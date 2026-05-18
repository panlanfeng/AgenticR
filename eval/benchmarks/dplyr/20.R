# NL: using mtcars, create a new column prev_mpg that contains the mpg value from the previous row
mutate(mtcars, prev_mpg = lag(mpg))
