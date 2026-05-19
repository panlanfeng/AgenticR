# SETUP: library(dplyr)
# NL: using mtcars, group by the cyl column and compute the mean mpg for each group
mtcars %>% group_by(cyl) %>% summarise(mean_mpg = mean(mpg))
