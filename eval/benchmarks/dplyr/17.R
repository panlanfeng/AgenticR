# EXPECTED_FORM: table
# SETUP: library(dplyr)
# NL: in mtcars, move the cyl column so it appears as the first column
relocate(mtcars, cyl)
