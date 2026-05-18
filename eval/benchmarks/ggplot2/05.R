# NL: using mtcars with cyl converted to a factor, make a boxplot of mpg grouped by cylinder count
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl), y = mpg)) + geom_boxplot()
