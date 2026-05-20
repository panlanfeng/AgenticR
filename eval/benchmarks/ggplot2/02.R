# EXPECTED_FORM: plot
# SETUP: library(ggplot2)
# NL: using the economics dataset from ggplot2, make a line chart of date on the x-axis and unemploy on the y-axis
library(ggplot2)
ggplot(economics, aes(x = date, y = unemploy)) + geom_line()
