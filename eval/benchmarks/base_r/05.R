# NL: compute the mean mpg for each cylinder group in mtcars using aggregate
aggregate(mpg ~ cyl, data = mtcars, FUN = mean)
