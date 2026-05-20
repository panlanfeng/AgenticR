# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using iris, make a scatter plot of Sepal.Length vs Sepal.Width with jittered points to reduce overlap
library(ggplot2)
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width)) + geom_jitter()
