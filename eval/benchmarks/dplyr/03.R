# NL: using mtcars, create a new column called hp_per_cyl that is hp divided by cyl
mutate(mtcars, hp_per_cyl = hp / cyl)
