# SETUP: library(ggplot2); library(dplyr)
# NL: using mtcars, first compute the mean mpg for each cyl, then make a bar chart of those means with cyl as the x-axis and mean mpg as the bar height
library(ggplot2)
library(dplyr)
mtcars %>% group_by(cyl) %>% summarise(mean_mpg = mean(mpg)) %>%
  ggplot(aes(x = factor(cyl), y = mean_mpg)) + geom_col()
