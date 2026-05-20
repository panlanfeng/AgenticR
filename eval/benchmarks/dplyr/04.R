# EXPECTED_FORM: number
# SETUP: library(dplyr)
# NL: compute the mean of the mpg column in mtcars
summarise(mtcars, mean_mpg = mean(mpg))
