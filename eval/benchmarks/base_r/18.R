# EXPECTED_FORM: model
# SETUP: 
# NL: run a one-way ANOVA comparing mpg across different cylinder counts in mtcars
anova(lm(mpg ~ factor(cyl), data = mtcars))
