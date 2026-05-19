# SETUP: library(dplyr)
# NL: using the iris dataset, compute the mean of Sepal.Length and Sepal.Width across all rows
summarise(iris, across(c(Sepal.Length, Sepal.Width), mean))
