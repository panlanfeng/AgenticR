# NL: using mtcars, make a scatter plot of mpg on the x-axis and wt on the y-axis
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point()
