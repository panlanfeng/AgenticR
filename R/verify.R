#' Deterministic R result contracts
#'
#' Contracts contain R-object checks evaluated in `.GlobalEnv`. This is the
#' preferred verifier for R because it inspects actual values, not just text.
#'
#' @keywords internal

agenticr_contract <- function(value = NULL) {
  if (is.null(value)) return(agenticr_env$result_contract)
  agenticr_env$result_contract <- value
  value
}

agenticr_eval_expr <- function(expression, envir = .GlobalEnv) {
  tryCatch(
    eval(parse(text = expression), envir = envir),
    error = function(e) structure(list(error = conditionMessage(e)), class = "agenticr_eval_error")
  )
}

agenticr_verify_check <- function(check, envir = .GlobalEnv) {
  type <- check$type %||% ""
  if (identical(type, "object_exists")) {
    ok <- exists(check$name %||% "", envir = envir, inherits = FALSE)
    return(list(ok = ok, detail = if (ok) "object exists" else "object missing"))
  }
  if (identical(type, "object_class")) {
    if (!exists(check$name %||% "", envir = envir, inherits = FALSE)) {
      return(list(ok = FALSE, detail = "object missing"))
    }
    value <- get(check$name, envir = envir)
    ok <- any(class(value) %in% (check$class %||% character(0)))
    return(list(ok = ok, detail = paste("class:", paste(class(value), collapse = "/"))))
  }
  if (identical(type, "dataframe_shape")) {
    if (!exists(check$name %||% "", envir = envir, inherits = FALSE)) {
      return(list(ok = FALSE, detail = "data frame missing"))
    }
    value <- get(check$name, envir = envir)
    ok <- is.data.frame(value) &&
      (is.null(check$rows) || nrow(value) == as.integer(check$rows)) &&
      (is.null(check$cols) || ncol(value) == as.integer(check$cols))
    return(list(ok = ok, detail = if (is.data.frame(value))
      paste0(nrow(value), " x ", ncol(value)) else "not a data frame"))
  }
  if (identical(type, "dataframe_columns")) {
    if (!exists(check$name %||% "", envir = envir, inherits = FALSE)) {
      return(list(ok = FALSE, detail = "data frame missing"))
    }
    value <- get(check$name, envir = envir)
    expected <- check$columns %||% character(0)
    ok <- is.data.frame(value) && all(expected %in% names(value))
    return(list(ok = ok, detail = if (is.data.frame(value))
      paste(names(value), collapse = ", ") else "not a data frame"))
  }
  if (identical(type, "value_equal")) {
    value <- agenticr_eval_expr(check$expression %||% "NULL", envir)
    if (inherits(value, "agenticr_eval_error")) {
      return(list(ok = FALSE, detail = value$error))
    }
    ok <- isTRUE(all.equal(value, check$equals, tolerance = 1e-6))
    return(list(ok = ok, detail = paste("value:", paste(value, collapse = ", "))))
  }
  if (identical(type, "value_true")) {
    value <- agenticr_eval_expr(check$expression %||% "FALSE", envir)
    if (inherits(value, "agenticr_eval_error")) {
      return(list(ok = FALSE, detail = value$error))
    }
    ok <- isTRUE(value)
    return(list(ok = ok, detail = paste("value:", value)))
  }
  if (identical(type, "error_free")) {
    value <- agenticr_eval_expr(check$expression %||% "NULL", envir)
    ok <- !inherits(value, "agenticr_eval_error")
    return(list(ok = ok, detail = if (ok) "expression ran" else value$error))
  }
  if (identical(type, "file_exists")) {
    ok <- file.exists(path.expand(check$path %||% ""))
    return(list(ok = ok, detail = if (ok) "file exists" else "file missing"))
  }
  if (identical(type, "file_contains")) {
    path <- path.expand(check$path %||% "")
    if (!file.exists(path)) return(list(ok = FALSE, detail = "file missing"))
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    count <- gregexpr(check$text %||% "", text, fixed = TRUE)[[1]]
    found <- if (identical(count[1], -1L)) 0L else length(count)
    expected <- check$count %||% NULL
    ok <- if (is.null(expected)) found > 0 else found == as.integer(expected)
    return(list(ok = ok, detail = paste("occurrences:", found)))
  }
  if (identical(type, "plot_layers")) {
    if (!exists(check$name %||% "", envir = envir, inherits = FALSE)) {
      return(list(ok = FALSE, detail = "plot object missing"))
    }
    value <- get(check$name, envir = envir)
    expected <- check$layers %||% character(0)
    actual <- if (inherits(value, "ggplot")) {
      vapply(value$layers, function(layer) class(layer$geom)[1], character(1))
    } else character(0)
    ok <- all(expected %in% actual)
    return(list(ok = ok, detail = paste(actual, collapse = ", ")))
  }
  list(ok = NA, detail = paste("unsupported check:", type))
}

agenticr_verify_contract <- function(contract = agenticr_env$result_contract,
                                     envir = .GlobalEnv) {
  if (is.null(contract) || length(contract$checks %||% list()) == 0) {
    return(list(
      satisfied = NA, verdict = "unknown",
      reason = "contract has no deterministic checks", checks = list()
    ))
  }
  checks <- contract$checks
  results <- lapply(checks, function(check) {
    result <- agenticr_verify_check(check, envir)
    c(list(type = check$type %||% ""), result)
  })
  failed <- Filter(function(x) identical(x$ok, FALSE), results)
  known <- Filter(function(x) !is.na(x$ok), results)
  if (length(known) == 0) {
    return(list(satisfied = NA, verdict = "unknown",
                reason = "no supported checks", checks = results))
  }
  satisfied <- length(failed) == 0
  list(
    satisfied = satisfied,
    verdict = if (satisfied) "pass" else "fail",
    reason = if (satisfied) "all R contract checks passed" else
      paste(vapply(failed, function(x) paste0(x$type, ": ", x$detail), character(1)),
            collapse = "; "),
    checks = results
  )
}

agenticr_format_contract <- function(contract) {
  if (is.null(contract)) return("(no contract)")
  paste0(
    "Goal: ", contract$goal %||% "", "\n",
    "Expected result: ", contract$expected_result %||% "", "\n",
    "Checks: ", paste(vapply(contract$checks %||% list(), function(check)
      jsonlite::toJSON(check, auto_unbox = TRUE, null = "null"), character(1)),
      collapse = " | ")
  )
}
