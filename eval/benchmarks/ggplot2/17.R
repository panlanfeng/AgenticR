# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using the mpg dataset from ggplot2, make a scatter plot of displ vs hwy with separate panels for different class values and different rows for drv values
library(ggplot2)
ggplot(mpg, aes(x = displ, y = hwy)) + geom_point() + facet_grid(drv ~ class)
