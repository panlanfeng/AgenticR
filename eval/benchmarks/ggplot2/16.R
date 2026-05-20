# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using mtcars, make a scatter plot of mpg vs wt and add text labels showing the car names from the rownames
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt, label = rownames(mtcars))) + geom_text(size = 3)
