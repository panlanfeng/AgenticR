#' Detect if input is natural language or R code
#'
#' Parse-first approach: if R's parser succeeds, it's R code.
#' If it fails, use the error message to decide: NL or incomplete R.
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

  # Parse check: if R parser succeeds (even empty expression = comment), it's R code
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
  # "unexpected end of input" → genuinely incomplete R (|>, +, open paren) → not NL
  if (grepl("unexpected end of input", parse_err)) {
    return(FALSE)
  }

  # "INCOMPLETE_STRING" → could be apostrophe (NL) or unclosed R string (code)
  if (grepl("INCOMPLETE_STRING", parse_err, ignore.case = TRUE)) {
    # Has R markers (assignment, pipes, function defs, common R functions) → R code
    r_indicators <- c(
      "<-", "->", "<<-", "->>",
      "%>%", "%<>%", "%T>%", "\\|>",
      "function\\(",
      "^library\\(", "^require\\(",
      "^setwd\\(", "^getwd\\(", "^source\\(",
      "^load\\(", "^save\\(", "^data\\(",
      "^lm\\(", "^glm\\(",
      "^ggplot\\(", "^geom_", "^aes\\(",
      "^filter\\(", "^mutate\\(", "^select\\(", "^arrange\\(",
      "^summarise\\(", "^group_by\\("
    )
    for (pattern in r_indicators) {
      if (grepl(pattern, input, perl = TRUE)) return(FALSE)
    }
    return(TRUE)
  }

  # Any other parse error → NL
  TRUE
}
