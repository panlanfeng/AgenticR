# SETUP: library(ggplot2)
# NL: using mtcars with cyl as a factor, make a violin plot of mpg for each cylinder count
library(ggplot2)
ggplot(mtcars, aes(x = factor(cyl), y = mpg)) + geom_violin()
