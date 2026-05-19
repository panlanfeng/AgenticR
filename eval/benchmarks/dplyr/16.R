# SETUP: library(dplyr)
# NL: create data frames a=data.frame(x=1:2, y=3:4) and b=data.frame(z=5:6, w=7:8), then row-bind them together
a <- data.frame(x = 1:2, y = 3:4)
b <- data.frame(x = 5:6, y = 7:8)
bind_rows(a, b)
