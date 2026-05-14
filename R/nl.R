#' Detect if input is natural language or R code
#'
#' Uses multi-factor heuristic:
#' - Word count >= 5 → likely NL
#' - Contains common NL patterns (question words, punctuation)
#' - Contains R-specific syntax → likely R
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
    "function\\(",               # Function definition
    "^library\\(",               # Library loading
    "^require\\(",               # Require loading
    "^install\\.packages\\(",   # Package install
    "^setwd\\(",                 # Working directory
    "^getwd\\(",                 # Working directory
    "^source\\(",                # Source
    "^load\\(",                  # Load data
    "^save\\(",                  # Save data
    "^data\\("                   # Load built-in data
  )

  for (pattern in r_indicators) {
    if (grepl(pattern, input, perl = TRUE)) {
      return(FALSE)
    }
  }

  # Strong NL indicators
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

  # Check for natural language punctuation patterns
  if (grepl("[?.!]$", input) && !grepl("[=+\\-*/<>(){}]", input)) {
    # Ends with punctuation and no math operators → likely NL
    word_count <- length(strsplit(input, "\\s+")[[1]])
    if (word_count >= 3) {
      return(TRUE)
    }
  }

  # Word count heuristic
  words <- strsplit(input, "\\s+")[[1]]
  word_count <- length(words)

  if (word_count >= 6) {
    # Long inputs are likely natural language
    return(TRUE)
  }

  if (word_count >= 4) {
    # Check for natural language function words
    nl_words <- c("the", "a", "an", "of", "in", "on", "at", "to", "for",
                  "with", "from", "by", "about", "into", "through", "during",
                  "and", "or", "but", "so", "because", "if", "when", "where",
                  "which", "who", "whom")
    lower_words <- tolower(words)
    nl_count <- sum(lower_words %in% nl_words)

    if (nl_count >= 2) {
      return(TRUE)
    }
  }

  # Try parsing as R: if it fails to parse, it's likely NL
  parsed <- tryCatch(
    parse(text = input),
    error = function(e) NULL
  )

  if (is.null(parsed) || length(parsed) == 0) {
    return(TRUE)
  }

  FALSE
}
