# EXPECTED_FORM: table
# SETUP: library(dplyr)
# NL: from mtcars, return only the rows with unique values in the cyl column
distinct(mtcars, cyl, .keep_all = TRUE)
