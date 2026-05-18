# NL: fit a logistic regression model predicting transmission type from mpg in mtcars
glm(am ~ mpg, data = mtcars, family = binomial)
