#!/usr/bin/env Rscript
# AgenticR Evaluation Runner — multi-turn with setup context
# Injects setup code as conversation history, then sends NL query

suppressPackageStartupMessages({
  library(agenticr)
  library(jsonlite)
  library(callr)
})

BENCHMARK_DIR <- file.path("benchmarks")
RESULTS_DIR <- file.path("results")
CATEGORIES <- c("dplyr", "ggplot2", "base_r")

dir.create(RESULTS_DIR, showWarnings = FALSE)

results_file <- file.path(RESULTS_DIR,
  paste0("results_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".jsonl"))

cat("AgenticR Evaluation Runner (multi-turn with context)\n")
cat("====================================================\n")

read_benchmark <- function(filepath) {
  lines <- readLines(filepath, warn = FALSE)
  setup_line <- grep("^# SETUP:", lines, value = TRUE)[1]
  nl_line <- grep("^# NL:", lines, value = TRUE)[1]
  if (is.na(nl_line)) stop("No NL description in ", filepath)
  setup <- if (!is.na(setup_line)) trimws(sub("^# SETUP:\\s*", "", setup_line)) else ""
  nl <- sub("^# NL:\\s*", "", nl_line)
  code_lines <- grep("^# (SETUP|NL):", lines, invert = TRUE, value = TRUE)
  code_lines <- code_lines[nchar(trimws(code_lines)) > 0]
  list(setup = setup, nl = nl, expected = paste(code_lines, collapse = "\n"))
}

run_in_session <- function(setup_code, nl_desc) {
  callr::r(function(setup, nl) {
    suppressPackageStartupMessages(library(agenticr))
    cfg <- agenticr:::load_config()
    if (cfg$api_key == "") stop("No API key configured")
    agenticr_env <- get("agenticr_env", envir = asNamespace("agenticr"))
    agenticr_env$config <- cfg
    agenticr_env$ask_permission <- function(p) FALSE

    process_with_agent <- get("process_with_agent", envir = asNamespace("agenticr"))

    # Inject setup as conversation context: execute it + add to conversation
    if (nchar(trimws(setup)) > 0) {
      # Execute setup silently
      tryCatch(eval(parse(text = setup), envir = .GlobalEnv), error = function(e) NULL)
      agenticr_env$conversation <- c(agenticr_env$conversation, list(list(
        role = "user", content = paste0("[R code executed]\n", setup)
      )))
    }

    process_with_agent(nl)

    conv <- agenticr_env$conversation
    codes <- character(0)
    for (msg in conv) {
      if (!is.null(msg$tool_calls)) {
        for (tc in msg$tool_calls) {
          args <- tryCatch(
            jsonlite::fromJSON(tc[["function"]]$arguments, simplifyVector = FALSE),
            error = function(e) list()
          )
          if (!is.null(args$code)) codes <- c(codes, args$code)
        }
      }
    }
    list(codes = codes)
  }, args = list(setup_code, nl_desc))
}

total <- 0
completed <- 0

for (cat in CATEGORIES) {
  cat_dir <- file.path(BENCHMARK_DIR, cat)
  files <- sort(list.files(cat_dir, pattern = "\\.R$", full.names = TRUE))
  total <- total + length(files)
  cat(sprintf("\n--- %s (%d benchmarks) ---\n", cat, length(files)))

  for (f in files) {
    bm <- read_benchmark(f)
    name <- basename(f)
    cat(sprintf("  %-8s ", name))

    result <- list(
      category = cat, file = name,
      setup = bm$setup, nl = bm$nl,
      expected_code = bm$expected,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )

    tryCatch({
      session_result <- run_in_session(bm$setup, bm$nl)
      result$generated_code <- paste(session_result$codes, collapse = "\n")
      result$error <- NULL
      completed <- completed + 1
      cat(sprintf("OK (%d chars)\n", nchar(result$generated_code)))
    }, error = function(e) {
      result$generated_code <- ""
      result$error <- conditionMessage(e)
      cat(sprintf("FAIL: %s\n", substr(result$error, 1, 60)))
    })

    line <- toJSON(result, auto_unbox = TRUE, force = TRUE)
    cat(line, "\n", file = results_file, append = TRUE)
  }
}

cat(sprintf("\nDone. %d/%d completed. Results: %s\n",
    completed, total, results_file))
