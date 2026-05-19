# SETUP: library(ggplot2)
# NL: using mtcars, make a horizontal bar chart showing the count of cars for each cylinder count
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl))) + geom_bar() + coord_flip()
