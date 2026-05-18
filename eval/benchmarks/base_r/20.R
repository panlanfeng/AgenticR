# NL: categorize the mpg values of mtcars into three equal-sized bins labeled low, medium, and high
cut(mtcars$mpg, breaks = 3, labels = c("low", "medium", "high"))
