# NL: using mtcars, make a bar chart showing the count of cars for each number of cylinders
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl))) + geom_bar()
