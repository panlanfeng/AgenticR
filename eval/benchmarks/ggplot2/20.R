# SETUP: library(ggplot2); library(dplyr)
# NL: using mtcars with cyl as a factor, compute the mean and standard deviation of mpg for each cylinder count, then plot the means as points with error bars for the standard deviation
library(ggplot2)
library(dplyr)
mtcars %>% group_by(cyl) %>% summarise(mean_mpg = mean(mpg), sd_mpg = sd(mpg)) %>%
  ggplot(aes(x = factor(cyl), y = mean_mpg)) + geom_point() + geom_errorbar(aes(ymin = mean_mpg - sd_mpg, ymax = mean_mpg + sd_mpg), width = 0.2)
