# EXPECTED_FORM: model
# SETUP: 
# NL: run a two-sample t-test comparing mpg between cars with automatic and manual transmission in mtcars
t.test(mpg ~ am, data = mtcars)
