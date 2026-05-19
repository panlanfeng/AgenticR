#!/usr/bin/env Rscript
# AgenticR Evaluation Scorer — case-by-case, context-aware
# Compares functional output, not surface formatting

suppressPackageStartupMessages({ library(jsonlite) })

args <- commandArgs(trailingOnly = TRUE)
results_file <- if (length(args) > 0) args[1] else {
  rf <- list.files("results", pattern = "^results_.*\\.jsonl$", full.names = TRUE)
  if (length(rf) == 0) stop("No results file found")
  sort(rf, decreasing = TRUE)[1]
}

cat("Scoring:", results_file, "\n\n")

lines <- readLines(results_file, warn = FALSE)
entries <- lapply(lines, fromJSON, simplifyVector = FALSE)

# ---- Evaluation helpers ----

eval_env <- new.env(parent = globalenv())
suppressMessages({
  library(dplyr); library(ggplot2)
  data(mtcars, iris, economics, mpg, envir = eval_env)
})

eval_output <- function(expected_code, generated_code, category) {
  exp_val <- tryCatch(eval(parse(text = expected_code), envir = eval_env), error = function(e) NULL)
  gen_val <- tryCatch(eval(parse(text = generated_code), envir = eval_env), error = function(e) NULL)
  if (is.null(exp_val) || is.null(gen_val)) return(0)

  # ggplot objects: compare layer types
  if (inherits(gen_val, "ggplot") && inherits(exp_val, "ggplot")) {
    gl <- sapply(gen_val$layers, function(l) class(l$geom)[1])
    el <- sapply(exp_val$layers, function(l) class(l$geom)[1])
    if (length(gl) != length(el)) return(0.5)
    return(sum(gl %in% el) / max(length(gl), length(el)))
  }

  # data frames: compare content ignoring class differences
  if (is.data.frame(gen_val) && is.data.frame(exp_val)) {
    common <- intersect(names(gen_val), names(exp_val))
    if (length(common) == 0) return(0)
    matches <- 0
    for (col in common) {
      if (isTRUE(all.equal(gen_val[[col]], exp_val[[col]], tolerance = 1e-6))) matches <- matches + 1
    }
    return(matches / length(common))
  }

  # numeric vectors: compare with tolerance
  if (is.numeric(gen_val) && is.numeric(exp_val)) {
    if (isTRUE(all.equal(gen_val, exp_val, tolerance = 1e-6))) return(1)
    return(0.5)
  }

  # model objects: compare coefficients
  if (inherits(gen_val, "lm") && inherits(exp_val, "lm")) {
    gc <- tryCatch(coef(gen_val), error = function(e) NULL)
    ec <- tryCatch(coef(exp_val), error = function(e) NULL)
    if (!is.null(gc) && !is.null(ec)) {
      if (isTRUE(all.equal(unname(gc), unname(ec), tolerance = 1e-6))) return(1)
      return(0.5)
    }
    return(0)
  }

  # default: all.equal
  if (isTRUE(all.equal(gen_val, exp_val, tolerance = 1e-6))) return(1)
  return(0)
}

# ---- Scoring loop ----

scores <- data.frame(category=character(), file=character(),
  exec=numeric(), output=numeric(), sim=numeric(), composite=numeric(),
  stringsAsFactors=FALSE)

for (e in entries) {
  cat(sprintf("%-10s ", e$file))
  expected <- e$expected_code
  generated <- e$generated_code %||% ""
  cat <- e$category

  # 1. Execution
  exec <- 0
  if (nchar(generated) > 0) {
    exec <- tryCatch({
      eval(parse(text = generated), envir = eval_env); 1
    }, error = function(er) 0)
  }
  cat(sprintf("exec=%d ", exec))

  # 2. Output — functional comparison
  output <- 0
  if (exec == 1 && nchar(expected) > 0) {
    output <- eval_output(expected, generated, cat)
  }
  cat(sprintf("output=%.1f ", output))

  # 3. Code similarity
  sim <- 0
  if (nchar(generated) > 0 && nchar(expected) > 0) {
    gt <- strsplit(gsub("\\s+", " ", generated), " ")[[1]]
    et <- strsplit(gsub("\\s+", " ", expected), " ")[[1]]
    gt <- gt[nchar(gt) > 0]; et <- et[nchar(et) > 0]
    if (length(et) > 0 && length(gt) > 0) {
      sim <- round(sum(tolower(gt) %in% tolower(et)) / max(length(gt), length(et)), 3)
    }
  }
  cat(sprintf("sim=%.2f ", sim))

  composite <- round(exec * 0.3 + output * 0.5 + sim * 0.2, 3)
  cat(sprintf("-> %.3f\n", composite))

  scores <- rbind(scores, data.frame(category=cat, file=e$file,
    exec=exec, output=output, sim=sim, composite=composite, stringsAsFactors=FALSE))
}

cat("\n========== Summary ==========\n\n")
for (cat in unique(scores$category)) {
  s <- scores[scores$category == cat, ]
  cat(sprintf("%-10s: exec=%.0f%%  output=%.2f  sim=%.2f  composite=%.3f  (%d)\n",
    cat, mean(s$exec)*100, mean(s$output), mean(s$sim), mean(s$composite), nrow(s)))
}
cat(sprintf("\n%-10s: exec=%.0f%%  output=%.2f  sim=%.2f  composite=%.3f  (%d)\n",
  "OVERALL", mean(scores$exec)*100, mean(scores$output), mean(scores$sim),
  mean(scores$composite), nrow(scores)))
