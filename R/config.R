#' Provider presets for common LLM APIs
#'
#' Use agentic_config(provider = "name") to switch providers.
#'
#' @keywords internal
PROVIDER_PRESETS <- list(
  deepseek = list(
    name = "DeepSeek",
    api_base = "https://api.deepseek.com",
    api_model = "deepseek-v4-pro",
    env_var = "DEEPSEEK_API_KEY"
  ),
  openai = list(
    name = "OpenAI",
    api_base = "https://api.openai.com/v1",
    api_model = "gpt-5.5",
    env_var = "OPENAI_API_KEY"
  ),
  anthropic = list(
    name = "Anthropic",
    api_base = "https://api.anthropic.com/v1",
    api_model = "claude-opus-4-7",
    env_var = "ANTHROPIC_API_KEY"
  ),
  google = list(
    name = "Google Gemini",
    api_base = "https://generativelanguage.googleapis.com/v1beta/openai",
    api_model = "gemini-3.1-pro-preview",
    env_var = "GOOGLE_API_KEY"
  ),
  glm = list(
    name = "Zhipu GLM",
    api_base = "https://open.bigmodel.cn/api/paas/v4",
    api_model = "glm-5.1",
    env_var = "GLM_API_KEY"
  ),
  kimi = list(
    name = "Moonshot Kimi",
    api_base = "https://api.moonshot.cn/v1",
    api_model = "kimi-k2-thinking",
    env_var = "KIMI_API_KEY"
  ),
  minimax = list(
    name = "MiniMax",
    api_base = "https://api.minimax.chat/v1",
    api_model = "MiniMax-M2.7",
    env_var = "MINIMAX_API_KEY"
  ),
  qwen = list(
    name = "Alibaba Qwen",
    api_base = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    api_model = "qwen3.6-plus",
    env_var = "QWEN_API_KEY"
  ),
  xai = list(
    name = "xAI",
    api_base = "https://api.x.ai/v1",
    api_model = "grok-4.3",
    env_var = "XAI_API_KEY"
  ),
  openrouter = list(
    name = "OpenRouter",
    api_base = "https://openrouter.ai/api/v1",
    api_model = "openrouter/auto",
    env_var = "OPENROUTER_API_KEY"
  ),
  siliconflow = list(
    name = "SiliconFlow",
    api_base = "https://api.siliconflow.cn/v1",
    api_model = "deepseek-ai/DeepSeek-V4-Flash",
    env_var = "SILICONFLOW_API_KEY"
  ),
  perplexity = list(
    name = "Perplexity",
    api_base = "https://api.perplexity.ai",
    api_model = "sonar-pro",
    env_var = "PERPLEXITY_API_KEY"
  ),
  mistral = list(
    name = "Mistral AI",
    api_base = "https://api.mistral.ai/v1",
    api_model = "mistral-large-2512",
    env_var = "MISTRAL_API_KEY"
  ),
  bedrock = list(
    name = "Amazon Bedrock",
    api_base = "https://bedrock-runtime.us-east-1.amazonaws.com",
    api_model = "anthropic.claude-opus-4-7-v1:0",
    env_var = "AWS_ACCESS_KEY_ID"
  ),
  custom = list(
    name = "Custom",
    api_base = "",
    api_model = "",
    env_var = NA_character_
  )
)

#' Auto-detect API key from well-known environment variables
#'
#' Checks provider-specific env vars first, then AGENTICR_API_KEY.
#' Returns list(api_key, api_base, api_model, provider_name) or NULL.
#'
#' @keywords internal
auto_detect_key <- function() {
  for (key in names(PROVIDER_PRESETS)) {
    preset <- PROVIDER_PRESETS[[key]]
    env_var <- preset$env_var
    if (is.na(env_var)) next
    value <- Sys.getenv(env_var, unset = "")
    if (nchar(value) > 0) {
      return(list(
        api_key = value,
        api_base = preset$api_base,
        api_model = preset$api_model,
        provider = key
      ))
    }
  }
  value <- Sys.getenv("AGENTICR_API_KEY", unset = "")
  if (nchar(value) > 0) {
    return(list(
      api_key = value,
      api_base = Sys.getenv("AGENTICR_API_BASE", unset = "https://api.deepseek.com/v1"),
      api_model = Sys.getenv("AGENTICR_MODEL", unset = "deepseek-chat"),
      provider = "custom"
    ))
  }
  NULL
}

#' Read and manage configuration
#'
#' Configuration sources (in priority order):
#' 1. Environment variables: AGENTICR_API_KEY, AGENTICR_API_BASE, AGENTICR_MODEL
#' 2. Provider-specific env vars: DEEPSEEK_API_KEY, OPENAI_API_KEY, etc.
#' 3. Config file: ~/.agenticr/config.yml
#' 4. In-session: agentic_config(key = "value")
#'
#' @param ... Named arguments to set (api_key, api_base, api_model, provider, temperature, max_tokens)
#' @param save If TRUE, save configuration to ~/.agenticr/config.yml
#' @export
agentic_config <- function(..., save = FALSE) {
  cfg <- agenticr_env$config
  args <- list(...)

  if (!is.null(args$provider)) {
    provider <- tolower(args$provider)
    preset <- PROVIDER_PRESETS[[provider]]
    if (is.null(preset)) {
      cli::cli_alert_warning("Unknown provider '{provider}'. Use one of: {.val {names(PROVIDER_PRESETS)}}")
    } else {
      cfg$provider <- provider
      if (nchar(preset$api_base) > 0) {
        cfg$api_base <- preset$api_base
      }
      if (nchar(preset$api_model) > 0) {
        cfg$api_model <- preset$api_model
      }
      env_var <- preset$env_var
      if (!is.na(env_var)) {
        key <- Sys.getenv(env_var, unset = "")
        if (nchar(key) > 0) {
          cfg$api_key <- key
        }
      }
      cli::cli_alert_success("Provider set to {preset$name} ({cfg$api_model})")
    }
  }

  for (name in c("api_key", "api_base", "api_model", "temperature", "max_tokens", "max_rounds", "provider")) {
    if (!is.null(args[[name]])) {
      cfg[[name]] <- args[[name]]
    }
  }

  if (save) {
    save_config(cfg)
  }

  assign("config", cfg, envir = agenticr_env)
  invisible(cfg)
}

#' Interactive setup wizard
#'
#' Guides user through API key and provider configuration interactively.
#'
#' @export
agentic_setup <- function() {
  cli::cli_h1("AgenticR Setup")

  auto <- auto_detect_key()
  if (!is.null(auto)) {
    cli::cli_alert_info("Auto-detected {.val {auto$provider}} API key")
    ans <- readline(paste0("Use the detected key? [Y/n] "))
    if (tolower(trimws(ans)) != "n") {
      agentic_config(
        api_key = auto$api_key,
        api_base = auto$api_base,
        api_model = auto$api_model,
        provider = auto$provider,
        save = TRUE
      )
      cli::cli_alert_success("Configuration saved with {auto$provider}")
      print.agenticr_config(agenticr_env$config)
      return(invisible())
    }
  }

  cli::cli_h2("Select Provider")
  provider_names <- sort(names(PROVIDER_PRESETS))
  for (i in seq_along(provider_names)) {
    p <- PROVIDER_PRESETS[[provider_names[i]]]
    cli::cli_li("{i}. {p$name} ({provider_names[i]})")
  }

  choice <- readline("Choose provider [1]: ")
  if (choice == "") choice <- "1"
  provider <- provider_names[as.integer(choice)]
  if (is.na(provider)) {
    cli::cli_alert_danger("Invalid choice")
    return(invisible())
  }

  preset <- PROVIDER_PRESETS[[provider]]
  cli::cli_text("")
  cli::cli_alert_info("Provider: {preset$name}")
  cli::cli_alert_info("Endpoint: {preset$api_base}")

  key_hint <- if (is.na(preset$env_var)) "your-api-key" else paste0("your ", preset$env_var)
  cat(paste0("Enter API key (", key_hint, "): "))
  api_key <- readline()
  if (api_key == "") {
    cli::cli_alert_danger("No API key entered. Setup cancelled.")
    return(invisible())
  }

  model <- readline(paste0("Model [", preset$api_model, "]: "))
  if (model == "") model <- preset$api_model

  agentic_config(
    api_key = api_key,
    api_base = preset$api_base,
    api_model = model,
    provider = provider,
    save = TRUE
  )

  cli::cli_text("")
  cli::cli_alert_success("Configuration saved!")
  print.agenticr_config(agenticr_env$config)
  invisible()
}

#' Load config from file and environment
#'
#' @keywords internal
load_config <- function() {
  cfg <- list(
    api_key = "",
    api_base = "https://api.deepseek.com",
    api_model = "deepseek-v4-pro",
    provider = "deepseek",
    max_tokens = 4096,
    temperature = 0.1,
    max_rounds = 10
  )

  # 1. Config file overrides defaults
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
      if (!is.null(file_cfg[[name]]) && !identical(file_cfg[[name]], "")) {
        cfg[[name]] <- file_cfg[[name]]
      }
    }
  }

  # 2. Environment variables override config file
  auto <- auto_detect_key()
  if (!is.null(auto)) {
    cfg$api_key <- auto$api_key
    cfg$api_base <- auto$api_base
    cfg$api_model <- auto$api_model
    cfg$provider <- auto$provider
  }

  env_key <- Sys.getenv("AGENTICR_API_KEY", unset = "")
  if (nchar(env_key) > 0) {
    cfg$api_key <- env_key
  }
  env_base <- Sys.getenv("AGENTICR_API_BASE", unset = "")
  if (nchar(env_base) > 0) {
    cfg$api_base <- env_base
  }
  env_model <- Sys.getenv("AGENTICR_MODEL", unset = "")
  if (nchar(env_model) > 0) {
    cfg$api_model <- env_model
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
      "No API key configured. Use agentic_setup() or one of:\n",
      "  agentic_config(api_key = \"sk-...\", save = TRUE)\n",
      "  agentic_config(provider = \"deepseek\")\n",
      "Or set AGENTICR_API_KEY or provider-specific env var."
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
  if (!is.null(x$provider)) {
    cli::cli_li("Provider: {x$provider}")
  }
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
  cli::cli_li("Max rounds: {x$max_rounds}")
}

#' List available provider presets
#'
#' @export
agentic_providers <- function() {
  cli::cli_h2("Available Providers")
  for (key in sort(names(PROVIDER_PRESETS))) {
    p <- PROVIDER_PRESETS[[key]]
    env <- if (is.na(p$env_var)) "(none)" else p$env_var
    key_found <- if (is.na(p$env_var)) {
      "?"
    } else if (nchar(Sys.getenv(p$env_var, unset = "")) > 0) {
      cli::col_green("key found")
    } else {
      cli::col_red("not set")
    }
    cli::cli_li("{.val {key}} - {p$name} ({p$api_model}) [{env}: {key_found}]")
  }
  invisible()
}
