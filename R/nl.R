#' Detect if input is natural language or R code
#'
#' Conservative approach: only flag as NL when there are strong NL signals
#' or the R parser fails. When in doubt, treat as R code.
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

  # Strong R indicators: if present, it's R code
  r_indicators <- c(
    "<-", "->", "<<-", "->>",  # Assignment
    "%>%", "%<>%", "%T>%",      # Pipes
    "\\|>",                      # Native pipe (escaped)
    "function\\(",               # Function definition
    "^library\\(",               # Library loading
    "^require\\(",               # Require loading
    "^install\\.packages\\(",   # Package install
    "^setwd\\(",                 # Working directory
    "^getwd\\(",                 # Working directory
    "^source\\(",                # Source
    "^load\\(",                  # Load data
    "^save\\(",                  # Save data
    "^data\\(",                  # Load built-in data
    "^lm\\(",                    # Linear model
    "^glm\\(",                   # Generalized linear model
    "^\\s*#"                     # R comment (possibly indented)
  )

  for (pattern in r_indicators) {
    if (grepl(pattern, input, perl = TRUE)) {
      return(FALSE)
    }
  }

  # Parse check: if R parser succeeds, it's valid R code
  parse_err <- ""
  parsed <- tryCatch(
    parse(text = input),
    error = function(e) {
      parse_err <<- e$message
      NULL
    }
  )
  if (!is.null(parsed) && length(parsed) > 0) {
    return(FALSE)
  }

  # If parse failed with only an apostrophe (INCOMPLETE_STRING) and no
  # R indicators were found above, it's natural language
  if (grepl("INCOMPLETE_STRING", parse_err, ignore.case = TRUE)) {
    return(TRUE)
  }

  # Strong NL indicators — only these trigger NL classification
  nl_indicators <- c(
    "^what\\s", "^how\\s", "^why\\s", "^when\\s", "^where\\s",
    "^can you\\s", "^could you\\s", "^would you\\s",
    "^please\\s", "^show me\\s", "^tell me\\s", "^explain\\s",
    "^help me\\s", "^find\\s", "^search\\s", "^list\\s",
    "^describe\\s", "^summarize\\s", "^analyze\\s",
    "^create\\s", "^make\\s", "^build\\s", "^generate\\s",
    "^plot\\s", "^chart\\s", "^graph\\s", "^visualize\\s",
    "^draw\\s", "^display\\s", "^show\\s",
    "^i need\\s", "^i want\\s", "^i have\\s", "^i\'d like\\s"
  )

  for (pattern in nl_indicators) {
    if (grepl(pattern, input, ignore.case = TRUE, perl = TRUE)) {
      return(TRUE)
    }
  }

  # Punctuation patterns: ends with ? or ! and no math operators
  if (grepl("[?.!]$", input) && !grepl("[=+*/<>(){}-]", input)) {
    word_count <- length(strsplit(input, "\\s+")[[1]])
    if (word_count >= 3) {
      return(TRUE)
    }
  }

  # Default: treat as R code (conservative)
  FALSE
}
