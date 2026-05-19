# SETUP: library(dplyr)
# NL: using mtcars, add a column called efficient that is TRUE if mpg is greater than 25, FALSE otherwise
mutate(mtcars, efficient = if_else(mpg > 25, TRUE, FALSE))
