# SETUP: library(ggplot2)
# NL: using mtcars, make a scatter plot of mpg vs wt and add a smoothed regression line
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point() + geom_smooth(method = "lm")
