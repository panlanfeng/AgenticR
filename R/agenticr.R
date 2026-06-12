#' AgenticR: AI-Powered R Console Assistant
#'
#' Type natural language or incorrect R code directly in the R console.
#' AgenticR routes natural language to an LLM agent that generates and
#' executes R code in the current R session. Valid R code is executed
#' directly with zero latency — no LLM overhead.
#'
#' Key features:
#' * AI-assisted interactive REPL via `agentic()`
#' * 15+ LLM provider presets with auto-detection
#' * 9 agent tools (code execution, data inspection, file ops, search)
#' * Real-time token streaming
#' * Cache-preserving context design for LLM prompt caching
#' * Opt-in skills system for prompt templates
#' * MCP (Model Context Protocol) support for external tools
#' * Multi-line R code continuation
#' * Error interceptor for standard R console
#' * Conversation memory extraction via sub-agent
#' * AGENTS.md support for custom instructions
#'
#' @name agenticr
#' @keywords internal
#' @importFrom utils tail globalVariables help
#' @examples
#' \dontrun{
#' # Configure and start
#' agentic_setup()
#' agentic()
#'
#' # Or use directly
#' agentic_config(provider = "deepseek")
#' agentic_chat("what is the mean of mpg in mtcars?")
#'
#' # Resume a previous session
#' agentic_sessions()
#' agentic_resume("20250515_120000_a1b2c3d4")
#' }
"_PACKAGE"

utils::globalVariables("output_lines")

`%||%` <- function(x, y) if (is.null(x)) y else x

agenticr_dir <- function() {
  tools::R_user_dir("agenticr", "data")
}

agenticr_env <- new.env(parent = emptyenv())

agenticr_env$config <- NULL
agenticr_env$is_active <- FALSE
agenticr_env$stable_summary <- NULL
agenticr_env$context_injected <- FALSE
agenticr_env$last_known_cwd <- ""
agenticr_env$max_context_tokens <- 131072L
agenticr_env$memory_dir <- file.path(agenticr_dir(), "memory")
agenticr_env$memory_file <- file.path(
  agenticr_env$memory_dir,
  "MEMORY.md"
)
agenticr_env$last_memory_extract_tokens <- 0L
agenticr_env$total_session_tokens <- 0L
agenticr_env$active_skills <- list()
agenticr_env$files_read <- list()
agenticr_env$todos <- list()
agenticr_env$tasks <- list()
agenticr_env$session_dir <- NULL
agenticr_env$session_id <- NULL
agenticr_env$outputs_dir <- NULL

.onLoad <- function(libname, pkgname) {
  cfg <- load_config()
  assign("config", cfg, envir = agenticr_env)
  if (!is.null(cfg$max_context_tokens)) {
    agenticr_env$max_context_tokens <- as.integer(cfg$max_context_tokens)
  }
}

.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    "AgenticR v", utils::packageVersion("agenticr"), "\n",
    "Type 'agentic_setup()' to configure your API key.\n",
    "Type 'agentic()' to start AI-assisted R session.\n",
    "Type 'agentic_providers()' to see supported providers."
  )
}
