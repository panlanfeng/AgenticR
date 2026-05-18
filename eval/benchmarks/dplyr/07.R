# NL: create two small data frames, a=data.frame(id=1:3, x=c("a","b","c")) and b=data.frame(id=2:4, y=c("x","y","z")), then join them by id keeping all rows from a
a <- data.frame(id = 1:3, x = c("a", "b", "c"), stringsAsFactors = FALSE)
b <- data.frame(id = 2:4, y = c("x", "y", "z"), stringsAsFactors = FALSE)
left_join(a, b, by = "id")
