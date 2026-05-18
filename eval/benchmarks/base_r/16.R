# NL: compute the 25th, 50th, and 75th percentiles of mpg from mtcars
quantile(mtcars$mpg, probs = c(0.25, 0.5, 0.75))
