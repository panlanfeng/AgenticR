# NL: using mtcars, make a histogram of the mpg values
library(ggplot2)
ggplot(mtcars, aes(x = mpg)) + geom_histogram(bins = 8)
