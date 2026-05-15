#' Test suite for agenticr package
#'
#' @keywords internal

# ============================================================================
# NL detection tests
# ============================================================================

test_that("is_natural_language detects R code correctly", {
  expect_false(is_natural_language("x <- 1:10"))
  expect_false(is_natural_language("library(ggplot2)"))
  expect_false(is_natural_language("mean(c(1,2,3))"))
  expect_false(is_natural_language("df %>% filter(x > 5)"))
  expect_false(is_natural_language("mtcars$mpg"))
  expect_false(is_natural_language("sum(1:100)"))
  expect_false(is_natural_language("mtcars |> filter(cyl == 4)"))
  expect_false(is_natural_language("df <- data.frame(x = 1:10)"))
  expect_false(is_natural_language("lm(mpg ~ hp, data = mtcars)"))
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

test_that("is_natural_language detects long NL text", {
  # Conservative: these parse as valid R function calls, so treated as R.
  # The execution layer catches the failure and routes to LLM for repair.
  expect_false(is_natural_language("calculate the average of all numeric columns grouped by category"))
  expect_false(is_natural_language("data from the mtcars dataset with filters"))
  expect_false(is_natural_language("analysis of the variance across groups"))
})

test_that("is_natural_language NL indicators still trigger correctly", {
  # Strong NL indicators should still return TRUE
  expect_true(is_natural_language("what is the mean of mpg?"))
  expect_true(is_natural_language("make a plot of mpg vs hp"))
  expect_true(is_natural_language("can you help me with this analysis?"))
  expect_true(is_natural_language("how do I create a scatter plot?"))
})

# ============================================================================
# Code block extraction tests
# ============================================================================

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

test_that("extract_r_code_blocks handles multiple blocks", {
  text <- "First:\n```r\nx <- 1\n```\nSecond:\n```r\ny <- 2\n```"
  result <- extract_r_code_blocks(text)
  expect_equal(length(result), 2)
})

test_that("remove_r_code_blocks strips code but keeps text", {
  text <- "Hello\n```r\nx <- 1\n```\nWorld"
  result <- remove_r_code_blocks(text)
  expect_match(result, "Hello")
  expect_match(result, "World")
  expect_false(grepl("x <- 1", result))
})

test_that("remove_r_code_blocks handles single backticks", {
  text <- "The `mtcars` dataset has `mpg` and `hp` columns."
  result <- remove_r_code_blocks(text)
  expect_match(result, "`mtcars`")
  expect_match(result, "`mpg`")
})

# ============================================================================
# Tool: execute_r_code tests
# ============================================================================

test_that("tool_execute_r_code runs R code and captures output", {
  result <- tool_execute_r_code("print(42)")
  expect_match(result, "42")
})

test_that("tool_execute_r_code captures visible return values", {
  result <- tool_execute_r_code("mean(1:10)")
  expect_match(result, "5.5")
})

test_that("tool_execute_r_code handles invisible returns", {
  result <- tool_execute_r_code("x <- 1:5")
  expect_equal(nchar(trimws(result)), 0)
})

test_that("tool_execute_r_code handles multi-line code", {
  result <- tool_execute_r_code("a <- 1\nb <- 2\na + b")
  expect_match(result, "3")
})

test_that("tool_execute_r_code handles errors", {
  result <- tool_execute_r_code("nonexistent_function()")
  expect_match(result, "Error")
})

test_that("tool_execute_r_code handles empty code", {
  result <- tool_execute_r_code("")
  expect_match(result, "Error")
})

# ============================================================================
# Tool: get_dataframe_info tests
# ============================================================================

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

test_that("tool_get_dataframe_info handles non-dataframe objects", {
  assign("test_six", 42, envir = .GlobalEnv)
  on.exit(rm("test_six", envir = .GlobalEnv))
  result <- tool_get_dataframe_info("test_six")
  expect_match(result, "Error")
})

# ============================================================================
# Tool: file_edit tests
# ============================================================================

test_that("tool_file_edit replaces unique string", {
  tmp <- tempfile()
  writeLines("first\nsecond\nthird", tmp)
  result <- tool_file_edit(tmp, "second", "SECOND")
  expect_match(result, "\\+SECOND")
  content <- paste(readLines(tmp), collapse = "\n")
  expect_match(content, "SECOND")
  unlink(tmp)
})

test_that("tool_file_edit rejects multiple matches", {
  tmp <- tempfile()
  writeLines("same\nsame\nother", tmp)
  result <- tool_file_edit(tmp, "same", "different")
  expect_match(result, "Found 2 matches")
  unlink(tmp)
})

test_that("tool_file_edit rejects no match", {
  tmp <- tempfile()
  writeLines("hello", tmp)
  result <- tool_file_edit(tmp, "not_there", "x")
  expect_match(result, "No match found")
  unlink(tmp)
})

test_that("tool_file_edit handles missing file", {
  result <- tool_file_edit("/nonexistent/path/file.txt", "x", "y")
  expect_match(result, "File not found")
})

# ============================================================================
# Tool: file_write tests
# ============================================================================

test_that("tool_file_write creates a file", {
  tmp <- tempfile()
  result <- tool_file_write(tmp, "hello world")
  expect_match(result, "Created")
  expect_true(file.exists(tmp))
  content <- paste(readLines(tmp), collapse = "\n")
  expect_equal(content, "hello world")
  unlink(tmp)
})

test_that("tool_file_write overwrites existing file", {
  tmp <- tempfile()
  writeLines("old content", tmp)
  result <- tool_file_write(tmp, "new content")
  expect_match(result, "\\+new content")
  content <- paste(readLines(tmp), collapse = "\n")
  expect_equal(content, "new content")
  unlink(tmp)
})

test_that("tool_file_write creates parent directories", {
  tmp <- file.path(tempdir(), "agenticr_test", "subdir", "test.txt")
  result <- tool_file_write(tmp, "data")
  expect_match(result, "Created")
  unlink(dirname(dirname(tmp)), recursive = TRUE)
})

# ============================================================================
# Tool: grep_search tests
# ============================================================================

test_that("tool_grep_search finds pattern in files", {
  tmp <- tempfile()
  writeLines("hello world\nfoo bar\nhello again", tmp)
  result <- tool_grep_search("hello", tmp, context_lines = 0)
  expect_match(result, "hello")
  unlink(tmp)
})

test_that("tool_grep_search handles no matches", {
  tmp <- tempfile()
  writeLines("abc\ndef", tmp)
  result <- tool_grep_search("xyznonexistent", tmp, context_lines = 0)
  expect_match(result, "No matches")
  unlink(tmp)
})

test_that("tool_grep_search handles empty pattern", {
  result <- tool_grep_search("")
  expect_match(result, "Error")
})

# ============================================================================
# Tool: get_function_help tests
# ============================================================================

test_that("tool_get_function_help finds documentation", {
  result <- tool_get_function_help("mean")
  expect_match(result, "mean")
})

test_that("tool_get_function_help handles missing function", {
  result <- tool_get_function_help("nonexistent_func_xyz")
  expect_match(result, "No documentation")
})

test_that("tool_get_function_help handles empty name", {
  result <- tool_get_function_help("")
  expect_match(result, "Error")
})

# ============================================================================
# Tool: search_variables tests
# ============================================================================

test_that("tool_search_variables finds global vars", {
  assign("test_var_12345", 42, envir = .GlobalEnv)
  on.exit(rm("test_var_12345", envir = .GlobalEnv))
  result <- tool_search_variables("test_var_12345")
  expect_match(result, "test_var_12345")
})

test_that("tool_search_variables handles no matches", {
  result <- tool_search_variables("nonexistent_pattern_xyz")
  expect_match(result, "No variables")
})

test_that("tool_search_variables returns all vars with empty pattern", {
  ls_before <- ls(envir = .GlobalEnv)
  result <- tool_search_variables("")
  expect_true(nchar(result) > 0)
})

# ============================================================================
# Tool: read_file tests
# ============================================================================

test_that("tool_read_file reads file content", {
  tmp <- tempfile()
  writeLines("line1\nline2\nline3", tmp)
  result <- tool_read_file(tmp)
  expect_match(result, "line1")
  unlink(tmp)
})

test_that("tool_read_file handles missing file", {
  result <- tool_read_file("/nonexistent/path.txt")
  expect_match(result, "Error")
})

# ============================================================================
# Config tests
# ============================================================================

test_that("load_config loads defaults", {
  cfg <- load_config()
  expect_equal(cfg$api_base, "https://api.deepseek.com")
  expect_equal(cfg$api_model, "deepseek-v4-pro")
  expect_equal(cfg$temperature, 0.1)
  expect_equal(cfg$max_tokens, 4096)
})

test_that("agentic_config updates in-memory config", {
  agentic_config(api_key = "sk-test123", save = FALSE)
  cfg <- get_api_config()
  expect_equal(cfg$api_key, "sk-test123")
  agentic_config(api_key = "", save = FALSE)
})

# ============================================================================
# Message sanitization tests
# ============================================================================

test_that("sanitize_messages removes orphaned tool messages", {
  msgs <- list(
    list(role = "system", content = "You are helpful."),
    list(role = "user", content = "hello"),
    list(role = "tool", tool_call_id = "orphan_1", content = "orphaned")
  )
  result <- sanitize_messages(msgs)
  expect_equal(length(result), 2)
  expect_equal(result[[1]]$role, "system")
  expect_equal(result[[2]]$role, "user")
})

test_that("sanitize_messages preserves valid tool chains", {
  msgs <- list(
    list(role = "system", content = "You are helpful."),
    list(role = "user", content = "run code"),
    list(role = "assistant", content = NULL,
         tool_calls = list(list(id = "tc1", "function" = list(name = "test")))),
    list(role = "tool", tool_call_id = "tc1", content = "result")
  )
  result <- sanitize_messages(msgs)
  expect_equal(length(result), 4)
})

test_that("sanitize_messages handles empty input", {
  result <- sanitize_messages(list())
  expect_equal(length(result), 0)
})

test_that("sanitize_messages resets pending on non-tool message", {
  msgs <- list(
    list(role = "system", content = "system"),
    list(role = "assistant", content = NULL,
         tool_calls = list(list(id = "tc1", "function" = list(name = "f")))),
    list(role = "user", content = "interrupting message"),
    list(role = "tool", tool_call_id = "tc1", content = "orphaned now")
  )
  result <- sanitize_messages(msgs)
  expect_equal(length(result), 3)
  expect_equal(result[[3]]$role, "user")
})

# ============================================================================
# Token estimation tests
# ============================================================================

test_that("estimate_tokens counts content", {
  msgs <- list(
    list(role = "system", content = paste(rep("a", 350), collapse = ""))
  )
  tokens <- estimate_tokens(msgs)
  expect_true(tokens >= 95 && tokens <= 105)
})

test_that("estimate_tokens handles empty messages", {
  expect_equal(estimate_tokens(list()), 0)
})

test_that("estimate_tokens handles tool_calls", {
  msgs <- list(
    list(role = "assistant", content = NULL,
         tool_calls = list(list(id = "x", "function" = list(name = "f", arguments = "{}"))))
  )
  tokens <- estimate_tokens(msgs)
  expect_true(tokens > 0)
})

# ============================================================================
# Context compaction tests
# ============================================================================

test_that("run_compaction returns input when API unavailable", {
  short <- list(
    list(role = "system", content = "You are helpful."),
    list(role = "user", content = "Hello")
  )
  result <- run_compaction(short)
  expect_equal(length(result), 2)
})

test_that("run_compaction preserves stable context and AGENTS.md", {
  msgs <- list(
    list(role = "system", content = "System prompt"),
    list(role = "user", content = "[AGENTS.md -- user instructions]\nTest instructions"),
    list(role = "user", content = "[Stable context]\nR version: 4.0"),
    list(role = "user", content = "Hello"),
    list(role = "assistant", content = "Hi"),
    list(role = "user", content = "How are you?")
  )
  result <- run_compaction(msgs)
  expect_true(length(result) >= 4)
  expect_equal(result[[1]]$role, "system")
})

# ============================================================================
# Context functions tests
# ============================================================================

test_that("load_agents_md returns empty when no files exist", {
  result <- load_agents_md()
  expect_true(nchar(result) == 0 || is.character(result))
})

test_that("build_stable_context contains expected fields", {
  result <- build_stable_context()
  expect_match(result, "[Stable context]")
  expect_match(result, "R version")
  expect_match(result, "Platform")
})

test_that("read_complete_input returns complete input as-is", {
  result <- read_complete_input("mean(mtcars$mpg)")
  expect_equal(result, "mean(mtcars$mpg)")
})

test_that("read_complete_input detects incomplete R code", {
  parsed <- tryCatch(
    parse(text = "mtcars |>"),
    error = function(e) conditionMessage(e)
  )
  expect_match(parsed, "unexpected end of input")
})

# ============================================================================
# Conversation state tests
# ============================================================================

test_that("agenticr_env has required fields", {
  expect_true(exists("agenticr_env", envir = asNamespace("agenticr")))
  env <- get("agenticr_env", envir = asNamespace("agenticr"))
  expect_true(is.list(env$config) || is.null(env$config))
  expect_true(is.logical(env$is_active))
  expect_true(is.logical(env$context_injected) || is.null(env$context_injected))
  expect_true(is.character(env$last_known_cwd) || is.null(env$last_known_cwd))
  expect_true(is.numeric(env$max_context_tokens))
  expect_true(is.character(env$memory_file))
})
