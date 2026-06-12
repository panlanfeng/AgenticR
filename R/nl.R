#' Detect if input is natural language or R code
#'
#' Parse-first approach with fast-path heuristics:
#' 1. Common NL starters (what, how, can, please, show, make, etc.) → NL
#' 2. parse() succeeds → R code (includes empty expressions = comments)
#' 3. "unexpected end of input" or "INCOMPLETE_STRING" → incomplete R
#' 4. Everything else → NL
#'
#' @param input Character string to classify
#' @return TRUE if input looks like natural language
#'
#' @keywords internal
is_natural_language <- function(input) {
  if (is.null(input) || nchar(trimws(input)) == 0) {
    return(FALSE)
  }

  input <- trimws(input)

  # Fast path: common NL starters skip parse() entirely
  nl_starters <- c("what", "how", "can", "please", "show", "make", "create",
                   "find", "get", "list", "calculate", "plot", "analyze",
                   "we", "could", "would", "help", "explain", "run",
                   "load", "compare", "summarize", "summarise", "describe",
                   "check", "tell")
  input_lower <- tolower(input)
  first_word <- sub("^(\\S+).*", "\\1", input_lower)
  if (nchar(first_word) > 0 && first_word %in% nl_starters) return(TRUE)
  if (grepl("^(i |we |could |would |can |please )", input_lower)) return(TRUE)

  # Parse check: if R parser succeeds, it's R code (includes comments)
  parse_err <- ""
  parsed <- tryCatch(
    parse(text = input),
    error = function(e) {
      parse_err <<- e$message
      NULL
    }
  )
  if (!is.null(parsed)) {
    return(FALSE)
  }

  # Parse failed — decide based on error type
  # "unexpected end of input" → incomplete R (|>, +, open paren)
  if (grepl("unexpected end of input", parse_err)) {
    return(FALSE)
  }

  # "INCOMPLETE_STRING" → detect if it's an R string or NL with apostrophe
  if (grepl("INCOMPLETE_STRING", parse_err, ignore.case = TRUE)) {
    for (op in c("<-", "->", "%>%", "|>", "function(")) {
      if (grepl(op, input, fixed = TRUE)) return(FALSE)
    }
    return(TRUE)
  }

  # Any other parse error → NL
  TRUE
}
