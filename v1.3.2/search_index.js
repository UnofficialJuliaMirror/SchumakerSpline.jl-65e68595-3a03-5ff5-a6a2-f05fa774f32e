var documenterSearchIndex = {"docs":
[{"location":"examples/#Examples-1","page":"Examples","title":"Examples","text":"","category":"section"},{"location":"examples/#","page":"Examples","title":"Examples","text":"Generating some example data","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"x = [1,1.5,2,2.5,3,3.5,4,4.5,5,5.5,6]\ny = log.(x) + sqrt.(x)\ngradients = missing","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"In this case we do not have gradients information and so gradients will be imputed from the x and y data.","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"We can create a spline and plot it with linear extrapolation.","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"using SchumakerSpline\nusing Plots\n########################\n# Linear Extrapolation #\nspline = Schumaker(x,y; extrapolation = Linear)\n# Now plotting the spline\nxrange =  collect(range(-5, stop=10, length=100))\nvalues  = evaluate.(spline, xrange)\nderivative_values  = evaluate.(spline, xrange, 1 )\nsecond_derivative_values  = evaluate.(spline, xrange , 2 )\nplot(xrange , values; label = \"Spline\")\nplot!(xrange, derivative_values; label = \"First Derivative\")\nplot!(xrange, second_derivative_values; label = \"Second Derivative\")","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"We can now do the same with constant extrapolation.","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"##########################\n# Constant Extrapolation #\nextrapolation = Constant\nspline = Schumaker(x,y; extrapolation = Constant)\n# Now plotting the spline\nxrange =  collect(range(-5, stop=10, length=100))\nvalues  = evaluate.(spline, xrange)\nderivative_values  = evaluate.(spline, xrange, 1 )\nsecond_derivative_values  = evaluate.(spline, xrange , 2 )\nplot(xrange , values; label = \"Spline\")\nplot!(xrange, derivative_values; label = \"First Derivative\")\nplot!(xrange, second_derivative_values; label = \"Second Derivative\")","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"If we did have gradient information we could get a better approximation by using it. In this case our gradients are:","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"analytical_first_derivative(e) = 1/e + 0.5 * e^(-0.5)\nfirst_derivs = analytical_first_derivative.(xrange)","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"and we can generate a spline using these gradients with:","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"spline = Schumaker(x,y; gradients = first_derivs)","category":"page"},{"location":"examples/#","page":"Examples","title":"Examples","text":"We could also have only specified the left or the right gradients using the left_gradient and right_gradient optional arguments.","category":"page"},{"location":"#SchumakerSpline.jl-1","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"","category":"section"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"A simple shape preserving spline implementation in Julia.","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"A Julia package to create a shape preserving spline. This is a shape preserving spline which is guaranteed to be monotonic and concave/convex if the data is monotonic and concave/convex. It does not use any numerical optimisation and is therefore quick and smoothly converges to a fixed point in economic dynamics problems including value function iteration. Analytical derivatives and integrals of the spline can easily be taken through the evaluate and evaluate_integral functions.","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"This package has the same basic functionality as the R package called schumaker.","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"If you want to do algebraic operations on splines you can also use a schumaker spline through the UnivariateFunctions package.","category":"page"},{"location":"#Optional-parameters-1","page":"SchumakerSpline.jl","title":"Optional parameters","text":"","category":"section"},{"location":"#Gradients.-1","page":"SchumakerSpline.jl","title":"Gradients.","text":"","category":"section"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"The gradients at each of the (x,y) points can be input to give more accuracy. If not supplied these are estimated from the points provided. It is also possible to input on the gradients on the edges of the x domain and have all of the intermediate gradients imputed.","category":"page"},{"location":"#Out-of-sample-prediction.-1","page":"SchumakerSpline.jl","title":"Out of sample prediction.","text":"","category":"section"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"There are three options for out of sample prediction.","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"Curve - This is where the quadratic curve that is present in the first and last interval are used to predict points before the first interval and after the last interval respectively.\nLinear - This is where a line is extended out before the first interval and after the last interval. The slope of the line is given by the derivative at the start of the first interval and end of the last interval.\nConstant - This is where the first and last y values are used for prediction before the first point of the interval and after the last part of the interval respectively.","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"","category":"page"},{"location":"#","page":"SchumakerSpline.jl","title":"SchumakerSpline.jl","text":"pages = [\"index.md\",\n         \"examples.md\"]\nDepth = 2","category":"page"}]
}