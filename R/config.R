#' Read and manage configuration
#'
#' Configuration can come from:
#' 1. Environment variables: AGENTICR_API_KEY, AGENTICR_API_BASE, AGENTICR_MODEL
#' 2. Config file: ~/.agenticr/config.yml
#' 3. In-session: agentic_config(key = "value")
#'
#' @param api_key Your API key (sk-...)
#' @param api_base API base URL (e.g. https://api.deepseek.com/v1)
#' @param api_model Model name (e.g. deepseek-chat)
#' @param save If TRUE, save configuration to ~/.agenticr/config.yml
#' @export
agentic_config <- function(api_key = NULL, api_base = NULL, api_model = NULL,
                           save = FALSE) {
  cfg <- agenticr_env$config

  if (!is.null(api_key)) {
    cfg$api_key <- api_key
  }
  if (!is.null(api_base)) {
    cfg$api_base <- api_base
  }
  if (!is.null(api_model)) {
    cfg$api_model <- api_model
  }

  if (save) {
    save_config(cfg)
  }

  assign("config", cfg, envir = agenticr_env)
  invisible(cfg)
}

#' Load config from file and environment
#'
#' @keywords internal
load_config <- function() {
  cfg <- list(
    api_key = Sys.getenv("AGENTICR_API_KEY", unset = ""),
    api_base = Sys.getenv("AGENTICR_API_BASE", unset = "https://api.deepseek.com/v1"),
    api_model = Sys.getenv("AGENTICR_MODEL", unset = "deepseek-chat"),
    max_tokens = 4096,
    temperature = 0.1,
    max_rounds = 10
  )

  config_file <- file.path(
    Sys.getenv("HOME", unset = "~"),
    ".agenticr",
    "config.yml"
  )

  if (file.exists(config_file)) {
    file_cfg <- tryCatch(
      yaml::read_yaml(config_file, eval.expr = FALSE),
      error = function(e) list()
    )
    for (name in names(file_cfg)) {
      if (cfg[[name]] == "" || is.null(cfg[[name]])) {
        cfg[[name]] <- file_cfg[[name]]
      }
    }
    if (cfg$api_key == "" && !is.null(file_cfg$api_key)) {
      cfg$api_key <- file_cfg$api_key
    }
  }

  cfg
}

#' Save current config to file
#'
#' @keywords internal
save_config <- function(cfg) {
  config_dir <- file.path(Sys.getenv("HOME", unset = "~"), ".agenticr")
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
  }
  config_file <- file.path(config_dir, "config.yml")
  yaml::write_yaml(cfg, config_file)
  cli::cli_alert_success("Config saved to {.file {config_file}}")
}

#' Get the current API configuration
#'
#' @keywords internal
get_api_config <- function() {
  cfg <- agenticr_env$config
  if (is.null(cfg) || cfg$api_key == "") {
    stop(
      "No API key configured. Set it with:\n",
      "  agentic_config(api_key = \"your-key-here\", save = TRUE)\n",
      "Or set AGENTICR_API_KEY environment variable."
    )
  }
  cfg
}

#' Print current configuration
#'
#' @param x An agenticr_config object
#' @param ... Additional arguments (ignored)
#' @export
print.agenticr_config <- function(x, ...) {
  cli::cli_h2("AgenticR Configuration")
  masked_key <- if (nchar(x$api_key) > 8) {
    paste0(substr(x$api_key, 1, 4), "****", substr(x$api_key, nchar(x$api_key) - 3, nchar(x$api_key)))
  } else {
    "****"
  }
  cli::cli_li("API Key: {masked_key}")
  cli::cli_li("API Base: {x$api_base}")
  cli::cli_li("Model: {x$api_model}")
  cli::cli_li("Temperature: {x$temperature}")
  cli::cli_li("Max tokens: {x$max_tokens}")
}
