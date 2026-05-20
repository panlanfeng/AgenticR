# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using mtcars, make a scatter plot of mpg vs wt with separate panels for each number of cylinders
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point() + facet_wrap(~ cyl)
