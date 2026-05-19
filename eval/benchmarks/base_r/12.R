# SETUP: 
# NL: create two small data frames, df1=data.frame(id=1:3, a=letters[1:3]) and df2=data.frame(id=2:4, b=letters[2:4]), then merge them by the id column
df1 <- data.frame(id = 1:3, a = letters[1:3], stringsAsFactors = FALSE)
df2 <- data.frame(id = 2:4, b = letters[2:4], stringsAsFactors = FALSE)
merge(df1, df2, by = "id")
