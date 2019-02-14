"""
This creates an enum which details how extrapolation from the interpolation domain should be done.
"""
@enum Schumaker_ExtrapolationSchemes begin
    Curve = 0
    Linear = 1
    Constant = 2
end


"""
    Schumaker(x::Array{Float64,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
                  left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
    Schumaker(x::Array{Int,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
                  left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
    Schumaker(x::Array{Date,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
                  left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
Creates a Schumaker spline.
### Takes
* x - A Float64 vector of x coordinates.
* y - A Float64 vector of y coordinates.
* extrapolation (optional) - This should be Curve, Linear or Constant specifying how to interpolate outside of the sample domain. By default it is Curve which extends out the first and last quadratic curves. The other options are Linear which extends the line (from first and last curve) out from the first and last point and Constant which extends out the y value at the first and last point.
* gradients (optional)- A Float64 vector of gradients at each point. If not supplied these are imputed from x and y.
* left_gradient - The gradient at the lowest value of x in the domain. This will override the gradient imputed or submitted in the gradients optional argument (if it is submitted there)
* right_gradient - The gradient at the highest value of x in the domain. This will override the gradient imputed or submitted in the gradients optional argument (if it is submitted there)

### Returns
* A Schumaker object which details the spline. This object can then be evaluated with evaluate or evaluate_integral.
 """
struct Schumaker
    IntStarts_::Array{Float64,1}
    IntEnds_::Array{Float64,1}
    coefficient_matrix_::Array{Float64,2}
    function Schumaker(x::Array{Float64,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
                       left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
        if length(x) == 0
            error("Zero length x vector is insufficient to create Schumaker Spline.")
        elseif length(x) == 1
            IntStarts = Array{Float64,1}(x)
            IntEnds = IntStarts
            SpCoefs = [0 0 y[1]]
            # Note that this hardcodes in constant extrapolation. This is only
            # feasible one as we do not have derivative or curve information.
            return new(IntStarts, IntEnds, SpCoefs)
        elseif length(x) == 2
            IntStarts = Array{Float64,1}([x[1]])
            IntEnds   = Array{Float64,1}([x[2]])
            linear_coefficient = (y[2]- y[1]) / (x[2]-x[1])
            SpCoefs = [0 linear_coefficient y[1]]
            # In this case it defaults to curve extrapolation (which is same as linear here)
            # So we just alter in case constant is specified.
            if extrapolation == Constant
                matrix_without_extrapolation = hcat(IntStarts, IntEnds, SpCoefs)
                matrix_with_extrapolation    = extrapolate(matrix_without_extrapolation, extrapolation, x, y)
                return new(matrix_with_extrapolation[:,1], matrix_with_extrapolation[:,2], matrix_with_extrapolation[:,3:5])
            else
                return new(IntStarts, IntEnds, SpCoefs)
            end
        end
        if ismissing(gradients)
           gradients = imputeGradients(x,y)
        end
        if !ismissing(left_gradient)
            gradients[1] = left_gradient
        end
        if !ismissing(right_gradient)
            gradients[length(gradients)] = right_gradient
        end
        IntStarts, IntEnds, SpCoefs = getCoefficientMatrix(x,y,gradients, extrapolation)
        return new(IntStarts, IntEnds, SpCoefs)
     end
    function Schumaker(x::Array{Int,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
         left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
        x_as_Float64s = convert.(Float64, x)
        return Schumaker(x_as_Float64s , y; gradients = gradients , extrapolation = extrapolation, left_gradient = left_gradient, right_gradient = right_gradient)
    end
    function Schumaker(x::Array{Date,1},y::Array{Float64,1} ; gradients::Union{Missing,Array{Float64,1}} = missing, extrapolation::Schumaker_ExtrapolationSchemes = Curve,
         left_gradient::Union{Missing,Float64} = missing, right_gradient::Union{Missing,Float64} = missing)
        days_as_ints = Dates.days.(x)
        return Schumaker(days_as_ints , y; gradients = gradients , extrapolation = extrapolation, left_gradient = left_gradient, right_gradient = right_gradient)
    end
    function Schumaker(IntStarts_::Array{Float64,1}, IntEnds_::Array{Float64,1}, coefficient_matrix_::Array{Float64,2})
        return new(IntStarts_, IntEnds_, coefficient_matrix_)
    end
end
Base.broadcastable(e::Schumaker) = Ref(e)

"""
Evaluates the spline at a point. The point can be specified as a Float64, Int or Date.
Derivatives can also be taken.
### Takes
 * spline - A Schumaker type spline
 * PointToExamine - The point at which to evaluate the integral
 * derivative - The derivative being sought. This should be 0 to just evaluate the spline, 1 for the first derivative or 2 for a second derivative.
 Higher derivatives are all zero (because it is a quadratic spline). Negative values do not give integrals. Use evaluate_integral instead.
### Returns
 * A Float64 value of the spline or appropriate derivative.
"""
function evaluate(spline::Schumaker, PointToExamine::Float64,  derivative::Int = 0)
    # Derivative of 0 means normal spline evaluation.
    # Derivative of 1, 2 are first and second derivatives respectively.
    IntervalNum = searchsortedlast(spline.IntStarts_, PointToExamine)
    IntervalNum = max(IntervalNum, 1)
    xmt = PointToExamine - spline.IntStarts_[IntervalNum]
    Coefs = spline.coefficient_matrix_[ IntervalNum , :]
    if derivative == 0
        return reshape(Coefs' * [xmt^2 xmt 1]', 1)[1]
    elseif derivative == 1
        return reshape(Coefs' * [2*xmt 1 0]', 1)[1]
    elseif derivative == 2
        return reshape(Coefs' * [2 0 0]', 1)[1]
    elseif derivative < 0
        error("This function cannot do integrals. Use evaluate_integral instead")
    else
        return 0.0
    end
end
function evaluate(spline::Schumaker, PointToExamine::Int,  derivative::Int = 0)
    point_as_Float64 = convert.(Float64, PointToExamine)
    return evaluate(spline,point_as_Float64,  derivative)
end
function evaluate(spline::Schumaker, PointToExamine::Date,  derivative::Int = 0)
    days_as_int = Dates.days.(PointToExamine)
    return evaluate(spline,days_as_int,  derivative)
end

"""
Estimates the integral of the spline between lhs and rhs. These end points can be input
as Float64s, Ints or Dates.
### Takes
 * spline - A Schumaker type spline
 * lhs - The left hand limit of the integral
 * rhs - The right hand limit of the integral

### Returns
 * A Float64 value of the integral.
"""
function evaluate_integral(spline::Schumaker, lhs::Float64, rhs::Float64)
    first_interval = searchsortedlast(spline.IntStarts_, lhs)
    last_interval = searchsortedlast(spline.IntStarts_, rhs)
    number_of_intervals = last_interval - first_interval
    if number_of_intervals == 0
        return section_integral(spline , lhs, rhs)
    elseif number_of_intervals == 1
        first = section_integral(spline , lhs , spline.IntStarts_[first_interval + 1])
        last  = section_integral(spline , spline.IntStarts_[last_interval]  , rhs)
        return first + last
    else
        interior_areas = 0.0
        first = section_integral(spline , lhs , spline.IntStarts_[first_interval + 1])
        for i in 1:(number_of_intervals-1)
            interior_areas = interior_areas + section_integral(spline ,  spline.IntStarts_[first_interval + i] , spline.IntStarts_[first_interval + i+1] )
        end
        last  = section_integral(spline , spline.IntStarts_[last_interval]  , rhs)
        return first + interior_areas + last
    end
end
function evaluate_integral(spline::Schumaker, lhs::Int, rhs::Int)
    return evaluate_integral(spline, convert(Float64, lhs), convert(Float64, rhs))
end
function evaluate_integral(spline::Schumaker, lhs::Date, rhs::Date)
    return evaluate_integral(spline, Dates.days.(lhs) , Dates.days.(rhs))
end
function section_integral(spline::Schumaker, lhs::Float64,  rhs::Float64)
    # Note that the lhs is used to infer the interval.
    IntervalNum = searchsortedlast(spline.IntStarts_, lhs)
    IntervalNum = max(IntervalNum, 1)
    Coefs = spline.coefficient_matrix_[ IntervalNum , :]
    r_xmt = rhs - spline.IntStarts_[IntervalNum]
    l_xmt = lhs - spline.IntStarts_[IntervalNum]
    return reshape(Coefs' * [(1/3)*r_xmt^3 0.5*r_xmt^2 r_xmt]', 1)[1] - reshape(Coefs' * [(1/3)*l_xmt^3 0.5*l_xmt^2 l_xmt]', 1)[1]
end


"""
find_derivative_spline(spline::Schumaker)
    Returns a SchumakerSpline that is the derivative of the input spline
"""
function find_derivative_spline(spline::Schumaker)
    coefficient_matrix = Array{Float64,2}(undef, size(spline.coefficient_matrix_)...   )
    coefficient_matrix[:,3] .= spline.coefficient_matrix_[:,2]
    coefficient_matrix[:,2] .= 2 .* spline.coefficient_matrix_[:,1]
    coefficient_matrix[:,1] .= 0.0
    return Schumaker(spline.IntStarts_, spline.IntEnds_, coefficient_matrix)
end


"""
find_root(spline::Schumaker)
Finds roots - This is handy because in many applications schumaker splines are monotonic and globally concave/convex and so it is easy to find roots.

"""
function find_roots(spline::Schumaker)
    roots = Array{Float64,1}(undef,0)
    first_derivatives = Array{Float64,1}(undef,0)
    second_derivatives = Array{Float64,1}(undef,0)
    len = length(spline.IntStarts_)
    constants = spline.coefficient_matrix_[:,3]
    if len < 2
        return (roots = roots, first_derivatives = first_derivatives, second_derivatives = second_derivatives)
    else
        for i in 1:(len-1)
            if abs(sign(constants[i]) - sign(constants[i+1])) > 0.5
                a = spline.coefficient_matrix_[i,1]
                b = spline.coefficient_matrix_[i,2]
                c = spline.coefficient_matrix_[i,3]
                if abs(a) > 1e-13
                    det = sqrt(b^2 - 4*a*c)
                    left_root  = (-b + det) / (2*a) # The x coordinate here is relative to spline.IntStarts_[i]. We want the smallest one that is to the right (ie positive)
                    right_root = (-b - det) / (2*a)
                    if left_root > 1e-13
                        append!(roots, left_root + spline.IntStarts_[i])
                        append!(first_derivatives, 2 * a * left_root + b)
                        append!(second_derivatives, 2 * a)
                    elseif right_root < spline.IntStarts_[i+1] - spline.IntStarts_[i] +  1e-13
                        append!(roots, right_root + spline.IntStarts_[i])
                        append!(first_derivatives, 2 * a * right_root + b)
                        append!(second_derivatives, 2 * a)
                    end
                else # My be linear. Cannot be constant or else it could not have jumped past zero.
                    new_root = spline.IntStarts_[i] - c/b
                    if !((length(roots) > 0) && (abs(new_root - last(roots)) < 1e-5))
                        append!(roots, spline.IntStarts_[i] - c/b)
                        append!(first_derivatives, b)
                        append!(second_derivatives, 0.0)
                    end
                end
            end
        end
    end
    return (roots = roots, first_derivatives = first_derivatives, second_derivatives = second_derivatives)
end

"""
find_optima(spline::Schumaker)
Finds optima - This is handy because in many applications schumaker splines are monotonic and globally concave/convex and so it is easy to find optima.

"""
function find_optima(spline::Schumaker)
    deriv_spline = find_derivative_spline(spline)
    root_info = find_roots(deriv_spline)
    optima = root_info.roots
    optima_types =  Array{Symbol,1}(undef,length(optima))
    for i in 1:length(optima)
        if root_info.first_derivatives[i] > 1e-15
            optima_types[i] = :Minimum
        elseif root_info.first_derivatives[i] < -1e-15
            optima_types = :Maximum
        else
            optima_types = :SaddlePoint
        end
    end
    return (optima = optima, optima_types = optima_types)
end

"""
    imputeGradients(x::Array{Float64,1}, y::Array{Float64,1})
Imputes gradients based on a vector of x and y coordinates.
"""
function imputeGradients(x::Array{Float64,1}, y::Array{Float64,1})
     n = length(x)
     # Judd (1998), page 233, second last equation
     L = sqrt.( (x[2:n]-x[1:(n-1)]).^2 + (y[2:n]-y[1:(n-1)]).^2)
     # Judd (1998), page 233, last equation
     d = (y[2:n]-y[1:(n-1)])./(x[2:n]-x[1:(n-1)])
     # Judd (1998), page 234, Eqn 6.11.6
     Conditionsi = d[1:(n-2)].*d[2:(n-1)] .> 0
     MiddleSiwithoutApplyingCondition = (L[1:(n-2)].*d[1:(n-2)]+L[2:(n-1)].* d[2:(n-1)]) ./ (L[1:(n-2)]+L[2:(n-1)])
     sb = Conditionsi .* MiddleSiwithoutApplyingCondition
     # Judd (1998), page 234, Second Equation line plus 6.11.6 gives this array of slopes.
     ff = [((-sb[1]+3*d[1])/2);  sb ;  ((3*d[n-1]-sb[n-2])/2)]
     return ff
 end

"""
Splits an interval into 2 subintervals and creates the quadratic coefficients
### Takes
 * s - A 2 entry Float64 vector with gradients at either end of the interval
 * z - A 2 entry Float64 vector with y values at either end of the interval
 * Smallt - A 2 entry Float64 vector with x values at either end of the interval

### Returns
 * A 2 x 5 matrix. The first column is the x values of start of the two subintervals. The second column is the ends. The last 3 columns are quadratic coefficients in two subintervals.
"""
function schumakerIndInterval(s::Array{Float64,1}, z::Array{Float64,1}, Smallt::Array{Float64,1})
   # The SchumakerIndInterval function takes in each interval individually
   # and returns the location of the knot as well as the quadratic coefficients in each subinterval.

   # Judd (1998), page 232, Lemma 6.11.1 provides this if condition:
   if (sum(s)*(Smallt[2]-Smallt[1]) == 2*(z[2]-z[1]))
     tsi = Smallt[2]
   else
     # Judd (1998), page 233, Algorithm 6.3 along with equations 6.11.4 and 6.11.5 provide this whole section
     delta = (z[2] -z[1])/(Smallt[2]-Smallt[1])
     Condition = ((s[1]-delta)*(s[2]-delta) >= 0)
     Condition2 = abs(s[2]-delta) < abs(s[1]-delta)
     if (Condition)
       tsi = sum(Smallt)/2
     elseif (Condition2)
       tsi = (Smallt[1] + (Smallt[2]-Smallt[1])*(s[2]-delta)/(s[2]-s[1]))
     else
       tsi = (Smallt[2] + (Smallt[2]-Smallt[1])*(s[1]-delta)/(s[2]-s[1]))
     end
   end

   # Judd (1998), page 232, 3rd last equation of page.
   alpha = tsi-Smallt[1]
   beta = Smallt[2]-tsi
   # Judd (1998), page 232, 4th last equation of page.
   sbar = (2*(z[2]-z[1])-(alpha*s[1]+beta*s[2]))/(Smallt[2]-Smallt[1])
   # Judd (1998), page 232, 3rd equation of page. (C1, B1, A1)
   Coeffs1 = [ (sbar-s[1])/(2*alpha)  s[1]  z[1] ]
   if (beta == 0)
     Coeffs2 = Coeffs1
   else
     # Judd (1998), page 232, 4th equation of page. (C2, B2, A2)
     Coeffs2 = [ (s[2]-sbar)/(2*beta)  sbar  Coeffs1 * [alpha^2, alpha, 1] ]
   end
   Machine4Epsilon = 4*eps()
     if (tsi  <  Smallt[1] + Machine4Epsilon )
         return [Smallt[1] Smallt[2] Coeffs2]
     elseif (tsi + Machine4Epsilon > Smallt[2] )
         return [Smallt[1] Smallt[2] Coeffs1]
     else
         return [Smallt[1] tsi Coeffs1 ; tsi Smallt[2] Coeffs2]
     end
 end

 """
 Calls SchumakerIndInterval many times to get full set of spline intervals and coefficients. Then calls extrapolation for out of sample behaviour
### Takes
 * gradients - A Float64 vector of gradients at each point
 * x - A Float64 vector of x coordinates
 * y - A Float64 vector of y coordinates
 * extrapolation - A string in ("Curve", "Linear", "Constant") that gives behaviour outside of interpolation range.

### Returns
 * A vector of interval starts
 * A vector of interval ends
 * A matrix of all coefficients
  """
 function getCoefficientMatrix(x::Array{Float64,1}, y::Array{Float64,1}, gradients::Array{Float64,1}, extrapolation::Schumaker_ExtrapolationSchemes)
   n = length(x)
   fullMatrix = schumakerIndInterval([gradients[1], gradients[2]], [y[1], y[2]], [x[1], x[2]] )
    for intrval = 2:(n-1)
      Smallt = [ x[intrval] , x[intrval + 1] ]
      s = [ y[intrval], y[intrval + 1] ]
      z = [ gradients[intrval], gradients[intrval + 1] ]
      intMatrix = schumakerIndInterval(z,s,Smallt)
      fullMatrix = vcat(fullMatrix,intMatrix)
    end
    fullMatrix = extrapolate(fullMatrix, extrapolation, x, y)
   return fullMatrix[:,1], fullMatrix[:,2], fullMatrix[:,3:5]
 end

"""
 Adds a row on top and bottom of coefficient matrix to give out of sample prediction.
### Takes
 * fullMatrix - output from GetCoefficientMatrix first few lines
 * extrapolation - A string in ("Curve", "Linear", "Constant") that gives behaviour outside of interpolation range.
 * x - A Float64 vector of x coordinates
 * y - A Float64 vector of y coordinates

### Returns
  * A new version of fullMatrix with out of sample prediction built into it.
"""
function extrapolate(fullMatrix::Array{Float64,2}, extrapolation::Schumaker_ExtrapolationSchemes, x::Array{Float64,1}, y::Array{Float64,1})
  if extrapolation == Curve
    return fullMatrix
  end
  dim = size(fullMatrix)[1]
  Botx   = fullMatrix[1,1]
  Boty   = y[1]
  if extrapolation == Linear
    BotB = fullMatrix[1 , 4]
    BotC   = Boty - BotB
  else
    BotB = 0.0
    BotC = Boty
  end
  BotRow = [ Botx-1, Botx, 0.0, BotB, BotC]
  Topx = fullMatrix[dim,2]
  Topy = y[length(y)]
  if extrapolation == Linear
    TopB = fullMatrix[dim ,4]
    TopC = Topy
  else
    TopB = 0.0
    TopC = Topy
  end
  TopRow = [ Topx, Topx + 1, 0.0 ,TopB ,TopC]
  fullMatrix = vcat(BotRow' , fullMatrix,  TopRow')
  return fullMatrix
end
