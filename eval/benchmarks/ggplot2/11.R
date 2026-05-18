# NL: using mtcars, make a scatter plot of mpg vs wt with a minimal clean theme
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point() + theme_minimal()
