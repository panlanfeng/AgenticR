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

make_eval_env <- function() {
  env <- new.env(parent = globalenv())
  suppressMessages({
    library(dplyr); library(ggplot2)
    data(mtcars, iris, economics, mpg, envir = env)
  })
  env
}

eval_output <- function(expected_code, generated_code, category, eval_env, expected_form) {
  exp_val <- tryCatch(eval(parse(text = expected_code), envir = eval_env), error = function(e) NULL)
  gen_val <- tryCatch(eval(parse(text = generated_code), envir = eval_env), error = function(e) NULL)
  if (is.null(exp_val) || is.null(gen_val)) return(0)

  # Smart matching: align shapes before comparing
  # If agent applied head() (fewer rows), match the expected to same shape
  if (is.data.frame(gen_val) && is.data.frame(exp_val) && nrow(gen_val) < nrow(exp_val)) {
    exp_val <- head(exp_val, nrow(gen_val))
  }
  # If generator returned fewer columns, subset expected
  if (is.data.frame(gen_val) && is.data.frame(exp_val) && ncol(gen_val) < ncol(exp_val)) {
    common <- intersect(names(gen_val), names(exp_val))
    if (length(common) > 0) {
      gen_val <- gen_val[, common, drop = FALSE]
      exp_val <- exp_val[, common, drop = FALSE]
    }
  }
  # If generated is numeric/scalar but expected is data.frame, extract from expected
  if (is.numeric(gen_val) && length(gen_val) <= 1 && is.data.frame(exp_val) && ncol(exp_val) == 1) {
    exp_val <- exp_val[[1]]
  }
  # If generated is atomic vector and expected is data.frame with 1 column, extract
  if (is.atomic(gen_val) && !is.list(gen_val) && is.data.frame(exp_val) && ncol(exp_val) == 1) {
    exp_val <- exp_val[[1]]
  }
  # If generated is table/count and expected is data.frame, convert expected to match
  if (inherits(gen_val, "table") && is.data.frame(exp_val)) {
    exp_val <- table(exp_val[[1]])
  }
  # If generated is character vector (e.g. names()) and expected is data.frame,
  # compare generated to the column names of expected
  if (is.character(gen_val) && is.data.frame(exp_val)) {
    exp_val <- names(exp_val)
  }
  # If generated is a vector from table()/summary and expected is data.frame,
  # count the expected column and compare
  if (is.atomic(gen_val) && !is.list(gen_val) && is.data.frame(exp_val) && ncol(exp_val) > 1) {
    exp_val <- table(exp_val[[1]])
  }
  # Column name normalization for data frames
  if (is.data.frame(gen_val) && is.data.frame(exp_val)) {
    names(gen_val) <- tolower(names(gen_val))
    names(exp_val) <- tolower(names(exp_val))
  }
  # If both are data.frames with same dims but different column names,
  # compare as unnamed matrices (values only, ignore names)
  if (is.data.frame(gen_val) && is.data.frame(exp_val) &&
      identical(dim(gen_val), dim(exp_val)) &&
      !identical(names(gen_val), names(exp_val))) {
    gen_val <- as.matrix(gen_val); colnames(gen_val) <- NULL
    exp_val <- as.matrix(exp_val); colnames(exp_val) <- NULL
  }

  # Normalize both to comparable form
  exp_norm <- normalize_for_compare(exp_val, expected_form)
  gen_norm <- normalize_for_compare(gen_val, expected_form)
  if (is.null(exp_norm) || is.null(gen_norm)) return(0)

  # ggplot objects: compare layer types
  if (inherits(gen_val, "ggplot") && inherits(exp_val, "ggplot")) {
    gl <- sapply(gen_val$layers, function(l) class(l$geom)[1])
    el <- sapply(exp_val$layers, function(l) class(l$geom)[1])
    if (length(gl) != length(el)) return(0.5)
    return(sum(gl %in% el) / max(length(gl), length(el)))
  }

  # Vector comparison: check first element + overall match
  if (is.atomic(gen_norm) && is.atomic(exp_norm) && !is.list(gen_norm) && !is.list(exp_norm)) {
    if (isTRUE(all.equal(gen_norm, exp_norm, tolerance = 1e-6))) return(1)
    # Partial match: first element matches?
    if (length(gen_norm) > 0 && length(exp_norm) > 0) {
      first_match <- isTRUE(all.equal(gen_norm[1], exp_norm[1], tolerance = 1e-6))
      if (first_match) return(0.7)
    }
    return(0.3)
  }

  # Data frame comparison: normalize to list of column vectors
  if (is.data.frame(gen_norm) && is.data.frame(exp_norm)) {
    common <- intersect(names(gen_norm), names(exp_norm))
    if (length(common) == 0) return(0)
    matches <- 0
    for (col in common) {
      if (isTRUE(all.equal(gen_norm[[col]], exp_norm[[col]], tolerance = 1e-6))) matches <- matches + 1
    }
    return(matches / length(common))
  }

  # Model objects: compare coefs
  if (inherits(gen_val, "lm") && inherits(exp_val, "lm")) {
    gc <- tryCatch(coef(gen_val), error = function(e) NULL)
    ec <- tryCatch(coef(exp_val), error = function(e) NULL)
    if (!is.null(gc) && !is.null(ec) && isTRUE(all.equal(unname(gc), unname(ec), tolerance = 1e-6))) return(1)
    return(0.5)
  }

  # Default: all.equal on normalized values
  if (isTRUE(all.equal(gen_norm, exp_norm, tolerance = 1e-6))) return(1)
  return(0)
}

normalize_for_compare <- function(val, expected_form) {
  # Convert to comparable form regardless of original type
  if (is.data.frame(val) || inherits(val, "tbl_df")) return(as.data.frame(val))
  if (inherits(val, c("table", "ftable"))) return(as.vector(val))
  if (is.matrix(val)) return(as.vector(val))
  if (is.factor(val)) return(as.character(val))
  if (is.list(val) && !is.data.frame(val)) return(unlist(val))
  val
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
  expected_form <- e$expected_form %||% ""
  eval_env <- make_eval_env()

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
    output <- eval_output(expected, generated, cat, eval_env, expected_form)
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
