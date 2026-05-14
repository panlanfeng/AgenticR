#' Test suite for agenticr package
#'
#' @keywords internal

# Test NL detection
test_that("is_natural_language detects R code correctly", {
  expect_false(is_natural_language("x <- 1:10"))
  expect_false(is_natural_language("library(ggplot2)"))
  expect_false(is_natural_language("mean(c(1,2,3))"))
  expect_false(is_natural_language("df %>% filter(x > 5)"))
  expect_false(is_natural_language("mtcars$mpg"))
  expect_false(is_natural_language("sum(1:100)"))
})

test_that("is_natural_language detects NL correctly", {
  expect_true(is_natural_language("make a plot of mpg vs hp"))
  expect_true(is_natural_language("how do I create a scatter plot?"))
  expect_true(is_natural_language("what is the mean of this column?"))
  expect_true(is_natural_language("can you analyze the mtcars dataset?"))
  expect_true(is_natural_language("please show me the summary statistics"))
  expect_true(is_natural_language("create a bar chart of the counts"))
  expect_true(is_natural_language("I need to fit a linear model to this data"))
  expect_true(is_natural_language("plot the relationship between age and income"))
})

test_that("is_natural_language handles edge cases", {
  expect_false(is_natural_language(""))
  expect_false(is_natural_language("x"))
  expect_false(is_natural_language("42"))
  expect_false(is_natural_language("ls()"))
})

# Test R code extraction
test_that("extract_r_code_blocks extracts code from markdown", {
  text <- "Here is some code:\n```r\nx <- 1\nprint(x)\n```"
  result <- extract_r_code_blocks(text)
  expect_equal(length(result), 1)
  expect_match(result[1], "x <- 1")

  text2 <- "```{r}\nggplot(mtcars, aes(x=mpg, y=hp)) + geom_point()\n```"
  result2 <- extract_r_code_blocks(text2)
  expect_equal(length(result2), 1)
})

test_that("extract_r_code_blocks handles no code blocks", {
  result <- extract_r_code_blocks("Just some text, no code.")
  expect_equal(length(result), 0)
})

# Test tool functions
test_that("tool_search_variables finds global vars", {
  assign("test_var_12345", 42, envir = .GlobalEnv)
  on.exit(rm("test_var_12345", envir = .GlobalEnv))

  result <- tool_search_variables("test_var_12345")
  expect_match(result, "test_var_12345")
})

test_that("tool_get_dataframe_info works with mtcars", {
  result <- tool_get_dataframe_info("mtcars")
  expect_match(result, "Data frame: mtcars")
  expect_match(result, "mpg")
  expect_match(result, "32 rows")
})

test_that("tool_get_dataframe_info handles missing vars", {
  result <- tool_get_dataframe_info("nonexistent_df_xyz")
  expect_match(result, "Error")
})

# Test config
test_that("load_config loads defaults", {
  cfg <- load_config()
  expect_equal(cfg$api_base, "https://api.deepseek.com/v1")
  expect_equal(cfg$api_model, "deepseek-chat")
})

# Test context compaction (requires API)
test_that("run_compaction returns input when API unavailable", {
  short <- list(
    list(role = "system", content = "You are helpful."),
    list(role = "user", content = "Hello")
  )
  result <- run_compaction(short)
  expect_equal(length(result), 2)
})
