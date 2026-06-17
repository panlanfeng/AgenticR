#' LLM integration tests for agenticr
#'
#' These tests require a configured API key (via agentic_config or env vars).
#' They are skipped if no API key is available.
#'
#' @keywords internal

has_api_key <- function() {
  if (nchar(Sys.getenv("AGENTICR_API_KEY", unset = "")) > 0) return(TRUE)
  if (nchar(Sys.getenv("DEEPSEEK_API_KEY", unset = "")) > 0) return(TRUE)
  tryCatch({
    cfg <- get_api_config()
    if (identical(cfg$provider, "local")) {
      # local provider requires a running ollama instance
      resp <- httr::GET("http://localhost:11434/api/tags", httr::timeout(2))
      return(httr::status_code(resp) == 200)
    }
    if (identical(cfg$provider, "custom") && nchar(cfg$base_url) > 0) {
      # custom provider: verify endpoint is reachable
      return(httr::status_code(
        httr::GET(paste0(cfg$base_url, "/models"), httr::timeout(2))) == 200)
    }
    # All other providers require a valid API key
    nchar(cfg$api_key) > 0
  }, error = function(e) FALSE)
}

skip_if_no_api <- function() {
  if (!has_api_key()) {
    testthat::skip("No API key configured")
  }
  key <- Sys.getenv("AGENTICR_API_KEY", unset = Sys.getenv("DEEPSEEK_API_KEY", unset = ""))
  if (nchar(key) > 0) {
    tryCatch(
      agentic_config(api_key = key, save = FALSE),
      error = function(e) NULL
    )
  }
}

# ============================================================================
# Simple NL queries — structural verification
# ============================================================================

test_that("LLM: simple calculation returns numeric result", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user", content = "what is 2 + 2? just the number")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  content <- resp$choices[[1]]$message$content
  expect_true(!is.null(content) || !is.null(resp$choices[[1]]$message$tool_calls))
})

test_that("LLM: NL query about mtcars uses tools", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user", content = "what is the mean of mpg in mtcars?")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  has_tools <- !is.null(msg$tool_calls) && length(msg$tool_calls) > 0
  has_content <- !is.null(msg$content) && nchar(msg$content) > 0
  expect_true(has_tools || has_content)
})

test_that("LLM: data inspection query triggers get_dataframe_info", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user", content = "show me the structure of the mtcars dataset")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  tool_names <- character(0)
  if (!is.null(msg$tool_calls)) {
    for (tc in msg$tool_calls) {
      tool_names <- c(tool_names, tc$`function`$name)
    }
  }
  expect_true("get_dataframe_info" %in% tool_names || !is.null(msg$content))
})

test_that("LLM: plot request generates R code", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user", content = "make a histogram of mpg from mtcars")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  tool_names <- character(0)
  if (!is.null(msg$tool_calls)) {
    for (tc in msg$tool_calls) {
      tool_names <- c(tool_names, tc$`function`$name)
    }
  }
  content_lower <- tolower(if (is.null(msg$content)) "" else msg$content)
  has_hist <- grepl("hist", content_lower) || "execute_r_code" %in% tool_names
  expect_true(has_hist)
})

# ============================================================================
# Tool execution verification
# ============================================================================

test_that("LLM: execute_r_code tool runs R code", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user", content = "run: mean(c(1,2,3,4,5))")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    result <- execute_tool(tc$`function`$name,
      jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE))
    expect_match(result, "3", all = FALSE)
  } else if (!is.null(msg$content)) {
    expect_match(msg$content, "3", all = FALSE)
  }
})

test_that("LLM: search_variables finds mtcars", {
  skip_if_no_api()
  result <- tool_search_variables("mtcars")
  expect_match(result, "mtcars")
})

test_that("LLM: get_dataframe_info works on mtcars", {
  skip_if_no_api()
  result <- tool_get_dataframe_info("mtcars")
  expect_match(result, "Data frame: mtcars")
  expect_match(result, "32 rows")
  expect_match(result, "mpg")
})

# ============================================================================
# Error repair — agent fixes broken R code
# ============================================================================

test_that("LLM: agent fixes missing function error", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "the user typed: meen(mtcars$mpg)\nThe error: could not find function \"meen\"\nFix it")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      expect_match(args$code, "mean", ignore.case = TRUE)
    }
  } else if (!is.null(msg$content)) {
    expect_match(msg$content, "mean", ignore.case = TRUE)
  }
})

test_that("LLM: agent fixes object not found", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "the user typed: head(mtcar)\nThe error: object 'mtcar' not found\nFix it")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      expect_match(tolower(args$code), "mtcars")
    }
  } else if (!is.null(msg$content)) {
    expect_match(tolower(msg$content), "mtcars")
  }
})

# ============================================================================
# Statistical analysis
# ============================================================================

test_that("LLM: t-test request generates correct analysis", {
  skip_if_no_api()
  skip_on_cran()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "run a t-test comparing mpg between 4 and 8 cylinder cars in mtcars")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      combined <- tolower(args$code)
      expect_true(grepl("t.test", combined) || grepl("mpg", combined))
    }
  } else if (!is.null(msg$content)) {
    expect_true(grepl("t.test", tolower(msg$content)) || grepl("mpg", tolower(msg$content)))
  }
})

test_that("LLM: correlation request generates cor or lm", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "what is the correlation between mpg and hp in mtcars?")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      combined <- tolower(args$code)
      expect_true(grepl("cor|lm", combined))
    }
  } else if (!is.null(msg$content)) {
    expect_true(nchar(msg$content) > 10)
  }
})

# ============================================================================
# Multi-turn conversation — context persistence
# ============================================================================

test_that("LLM: conversation context persists across turns", {
  skip_if_no_api()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$conversation <- list()
  agenticr_env$ask_permission <- function(prompt) FALSE

  agenticr:::process_with_agent("what columns does mtcars have? just list column names briefly")
  conv1_len <- length(agenticr_env$conversation)
  expect_true(conv1_len > 0)

  agenticr:::process_with_agent("now show the mean of the first column you listed")
  conv2_len <- length(agenticr_env$conversation)
  expect_true(conv2_len >= conv1_len)
})

test_that("LLM: multi-step analysis across turns", {
  skip_if_no_api()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$conversation <- list()
  agenticr_env$ask_permission <- function(prompt) FALSE

  expect_error(agenticr:::process_with_agent("look at the mtcars dataset structure"), NA)
  expect_error(agenticr:::process_with_agent("what is the average mpg for each cylinder group?"), NA)
  expect_error(agenticr:::process_with_agent("make a bar chart of those averages"), NA)
})

# ============================================================================
# Data transformation
# ============================================================================

test_that("LLM: group-by summarise uses aggregate or group_by", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "calculate mean mpg grouped by cyl in mtcars")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      combined <- tolower(args$code)
      expect_true(grepl("group_by|aggregate|tapply|by", combined))
    }
  }
})

test_that("LLM: filter request uses correct syntax", {
  skip_if_no_api()
  messages <- list(list(role = "system", content = SYSTEM_PROMPT))
  messages <- c(messages, list(list(role = "user",
    content = "show me cars in mtcars with mpg greater than 20")))
  resp <- chat_completion(messages, tools = get_tool_definitions())
  msg <- resp$choices[[1]]$message
  if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
    tc <- msg$tool_calls[[1]]
    if (tc$`function`$name == "execute_r_code") {
      args <- jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE)
      combined <- tolower(args$code)
      expect_true(grepl("filter|subset|\\[.*mpg", combined))
    }
  }
})

# ============================================================================
# Sanitization keeps message chains valid
# ============================================================================

test_that("LLM: tool_calls/tool pairing stays valid across turns", {
  skip_if_no_api()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$conversation <- list()
  agenticr_env$ask_permission <- function(prompt) FALSE

  expect_error(
    agenticr:::process_with_agent("what is the mean of mpg by cylinder in mtcars?"),
    NA
  )
  expect_error(
    agenticr:::process_with_agent("now show the count of cars per cylinder"),
    NA
  )
})

# ============================================================================
# Error-loop detection — integration test
# ============================================================================

test_that("LLM: agent completes repo-analysis task without silent hang", {
  skip_if_no_api()
  skip_on_cran()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$conversation <- list()
  agenticr_env$ask_permission <- function(prompt) FALSE

  expect_error(
    agenticr:::process_with_agent(
      "read the tests/testthat/test-llm.R file, summarize what it tests, and list 3 area of improvements. do not edit code."
    ),
    NA
  )
  conv <- agenticr_env$conversation
  expect_true(length(conv) > 0)
  # Verify the conversation has assistant content (not just errors)
  msgs <- Filter(function(m) m$role == "assistant" && nchar(m$content %||% "") > 20, conv)
  expect_true(length(msgs) > 0)
})
