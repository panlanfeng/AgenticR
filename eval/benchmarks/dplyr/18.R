# SETUP: library(dplyr)
# NL: from mtcars, extract the top 5 rows with the highest mpg values
slice_max(mtcars, mpg, n = 5)
