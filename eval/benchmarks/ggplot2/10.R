# NL: using mtcars, make a scatter plot of mpg vs wt and add the title "Fuel Efficiency vs Weight" and rename the x-axis label to "Miles Per Gallon"
library(ggplot2)
ggplot(mtcars, aes(x = mpg, y = wt)) + geom_point() + labs(title = "Fuel Efficiency vs Weight", x = "Miles Per Gallon")
