# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using the iris dataset, make a density plot of Sepal.Length
library(ggplot2)
ggplot(iris, aes(x = Sepal.Length)) + geom_density()
