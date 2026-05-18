#!/usr/bin/env Rscript
# AgenticR Evaluation Scorer
# Computes execution, output, and code similarity scores

suppressPackageStartupMessages({
  library(jsonlite)
})

args <- commandArgs(trailingOnly = TRUE)
results_file <- if (length(args) > 0) args[1] else {
  rf <- list.files("results", pattern = "^results_.*\\.jsonl$", full.names = TRUE)
  if (length(rf) == 0) stop("No results file found")
  sort(rf, decreasing = TRUE)[1]
}

cat("Scoring:", results_file, "\n\n")

lines <- readLines(results_file, warn = FALSE)
entries <- lapply(lines, fromJSON, simplifyVector = FALSE)

scores <- data.frame(
  category = character(0),
  file = character(0),
  exec = numeric(0),
  output = numeric(0),
  sim = numeric(0),
  composite = numeric(0),
  stringsAsFactors = FALSE
)

for (e in entries) {
  cat(sprintf("%-10s ", e$file))
  nl <- e$nl
  expected <- e$expected_code
  generated <- e$generated_code %||% ""

  # 1. Execution score: does generated code run without error?
  exec <- 0
  if (nchar(generated) > 0) {
    exec <- tryCatch({
      eval(parse(text = generated), envir = new.env(parent = baseenv()))
      1
    }, error = function(er) 0)
  }
  cat(sprintf("exec=%d ", exec))

  # 2. Output score: does generated output match expected?
  output <- 0
  if (exec == 1 && nchar(expected) > 0) {
    exp_out <- tryCatch(
      paste(utils::capture.output(eval(parse(text = expected))), collapse = "\n"),
      error = function(e) "ERROR"
    )
    gen_out <- tryCatch(
      paste(utils::capture.output(eval(parse(text = generated))), collapse = "\n"),
      error = function(e) "ERROR"
    )
    if (exp_out != "ERROR" && gen_out != "ERROR") {
      output <- if (trimws(exp_out) == trimws(gen_out)) 1 else 0
    }
  }
  cat(sprintf("output=%d ", output))

  # 3. Similarity score: normalized token edit distance
  sim <- 0
  if (nchar(generated) > 0 && nchar(expected) > 0) {
    gen_tokens <- strsplit(gsub("\\s+", " ", generated), " ")[[1]]
    exp_tokens <- strsplit(gsub("\\s+", " ", expected), " ")[[1]]
    gen_tokens <- gen_tokens[nchar(gen_tokens) > 0]
    exp_tokens <- exp_tokens[nchar(exp_tokens) > 0]
    n <- max(length(gen_tokens), length(exp_tokens))
    if (n > 0) {
      matches <- sum(tolower(gen_tokens) %in% tolower(exp_tokens))
      sim <- round(matches / n, 3)
    }
  }
  cat(sprintf("sim=%.2f ", sim))

  composite <- round(exec * 0.3 + output * 0.5 + sim * 0.2, 3)
  cat(sprintf("-> %.3f\n", composite))

  scores <- rbind(scores, data.frame(
    category = e$category, file = e$file,
    exec = exec, output = output, sim = sim, composite = composite,
    stringsAsFactors = FALSE
  ))
}

cat("\n========== Summary ==========\n\n")

for (cat in unique(scores$category)) {
  s <- scores[scores$category == cat, ]
  cat(sprintf("%-10s: exec=%.1f%%  output=%.1f%%  sim=%.2f  composite=%.3f  (%d examples)\n",
    cat,
    mean(s$exec) * 100,
    mean(s$output) * 100,
    mean(s$sim),
    mean(s$composite),
    nrow(s)
  ))
}

cat(sprintf("\n%-10s: exec=%.1f%%  output=%.1f%%  sim=%.2f  composite=%.3f  (%d total)\n",
  "OVERALL",
  mean(scores$exec) * 100,
  mean(scores$output) * 100,
  mean(scores$sim),
  mean(scores$composite),
  nrow(scores)
))
