# NL: using mtcars, make a scatter plot of mpg vs wt with points colored by the number of cylinders, and set the point size to 3
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt, color = factor(cyl))) + geom_point(size = 3)
