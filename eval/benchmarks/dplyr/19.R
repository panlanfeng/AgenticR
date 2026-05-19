# SETUP: library(dplyr)
# NL: create a vector v = c(1, NA, 3, NA, 5) and replace all NA values in it with 0
v <- c(1, NA, 3, NA, 5)
coalesce(v, 0)
