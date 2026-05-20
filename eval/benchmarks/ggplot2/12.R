# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using iris, make a scatter plot of Sepal.Length vs Sepal.Width with points colored by the Species column
library(ggplot2)
ggplot(iris, aes(x = Sepal.Length, y = Sepal.Width, color = Species)) + geom_point()
