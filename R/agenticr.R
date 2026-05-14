#' AgenticR: AI-Powered R Console Assistant
#'
#' Type natural language or incorrect R code directly in the R console.
#' AgenticR routes natural language to an LLM agent and executes normal
#' R code directly in the current session.
#'
#' @name agenticr
#' @keywords internal
#' @importFrom utils tail globalVariables
"_PACKAGE"

utils::globalVariables("output_lines")

agenticr_env <- new.env(parent = emptyenv())

agenticr_env$config <- NULL
agenticr_env$session_history <- list()
agenticr_env$is_active <- FALSE
agenticr_env$stable_summary <- NULL
agenticr_env$context_injected <- FALSE
agenticr_env$last_known_cwd <- ""
agenticr_env$max_context_tokens <- 128000L

.onLoad <- function(libname, pkgname) {
  assign("config", load_config(), envir = agenticr_env)
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "AgenticR v", utils::packageVersion("agenticr"), "\n",
    "Type 'agentic()' to start AI-assisted R session.\n",
    "Type 'agentic_config()' to set up your API key."
  )
}
