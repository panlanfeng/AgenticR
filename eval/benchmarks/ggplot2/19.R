# SETUP: library(ggplot2); library(dplyr)
# NL: create a correlation matrix from mtcars using cor(), reshape it into a long format, then plot it as a heatmap tile chart
library(ggplot2)
library(reshape2)
cor_mat <- cor(mtcars)
cor_long <- melt(cor_mat)
ggplot(cor_long, aes(x = Var1, y = Var2, fill = value)) + geom_tile()
