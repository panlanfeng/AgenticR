# EXPECTED_FORM: table
# SETUP: library(dplyr)
# NL: using mtcars, add a column called mpg_cat that is "high" if mpg is above 25, "medium" if mpg is between 15 and 25, and "low" otherwise
mutate(mtcars, mpg_cat = case_when(mpg > 25 ~ "high", mpg > 15 ~ "medium", TRUE ~ "low"))
