#' Detect if input is natural language or R code
#'
#' Parse-first approach. Only three rules:
#' 1. Contraction pattern (letter + apostrophe + letter) → NL
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

  # Contractions: letter + apostrophe + letter (don't, it's, what's, l'amour)
  if (grepl("[a-zA-Z]'[a-zA-Z]", input)) {
    return(TRUE)
  }

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

  # "INCOMPLETE_STRING" → contractions already caught above
  # For possessives and other non-contraction apostrophes, treat as NL
  # unless the input has R operators (real R code with unclosed string)
  if (grepl("INCOMPLETE_STRING", parse_err, ignore.case = TRUE)) {
    for (op in c("<-", "->", "%>%", "|>", "function(", "+")) {
      if (grepl(op, input, fixed = TRUE)) return(FALSE)
    }
    return(TRUE)
  }

  # Any other parse error → NL
  TRUE
}
