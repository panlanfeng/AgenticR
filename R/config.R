#' Provider presets for common LLM APIs
#'
#' Use agentic_config(provider = "name") to switch providers.
#'
#' @keywords internal
PROVIDER_PRESETS <- list(
  deepseek = list(
    name = "DeepSeek",
    base_url = "https://api.deepseek.com",
    model = "deepseek-v4-pro",
    env_var = "DEEPSEEK_API_KEY",
    max_tokens = 32768,
    max_context_tokens = 1048576,
    reasoning_effort = "medium"
  ),
  openai = list(
    name = "OpenAI",
    base_url = "https://api.openai.com/v1",
    model = "gpt-5.5",
    env_var = "OPENAI_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  anthropic = list(
    name = "Anthropic",
    base_url = "https://api.anthropic.com/v1",
    model = "claude-opus-4-7",
    env_var = "ANTHROPIC_API_KEY",
    max_tokens = 32768,
    max_context_tokens = 200000
  ),
  google = list(
    name = "Google Gemini",
    base_url = "https://generativelanguage.googleapis.com/v1beta/openai",
    model = "gemini-3.1-pro-preview",
    env_var = "GOOGLE_API_KEY",
    max_tokens = 8192,
    max_context_tokens = 1048576
  ),
  glm = list(
    name = "Zhipu GLM",
    base_url = "https://open.bigmodel.cn/api/paas/v4",
    model = "glm-5.1",
    env_var = "GLM_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  kimi = list(
    name = "Moonshot Kimi",
    base_url = "https://api.moonshot.cn/v1",
    model = "kimi-k2-thinking",
    env_var = "KIMI_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  minimax = list(
    name = "MiniMax",
    base_url = "https://api.minimax.chat/v1",
    model = "MiniMax-M2.7",
    env_var = "MINIMAX_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 1048576
  ),
  qwen = list(
    name = "Alibaba Qwen",
    base_url = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
    model = "qwen3.6-plus",
    env_var = "QWEN_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  xai = list(
    name = "xAI",
    base_url = "https://api.x.ai/v1",
    model = "grok-4.3",
    env_var = "XAI_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 1048576
  ),
  openrouter = list(
    name = "OpenRouter",
    base_url = "https://openrouter.ai/api/v1",
    model = "openrouter/auto",
    env_var = "OPENROUTER_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  siliconflow = list(
    name = "SiliconFlow",
    base_url = "https://api.siliconflow.cn/v1",
    model = "deepseek-ai/DeepSeek-V4-Flash",
    env_var = "SILICONFLOW_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  perplexity = list(
    name = "Perplexity",
    base_url = "https://api.perplexity.ai",
    model = "sonar-pro",
    env_var = "PERPLEXITY_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  mistral = list(
    name = "Mistral AI",
    base_url = "https://api.mistral.ai/v1",
    model = "mistral-large-2512",
    env_var = "MISTRAL_API_KEY",
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  bedrock = list(
    name = "Amazon Bedrock",
    base_url = "https://bedrock-runtime.us-east-1.amazonaws.com",
    model = "anthropic.claude-opus-4-7-v1:0",
    env_var = "AWS_ACCESS_KEY_ID",
    max_tokens = 32768,
    max_context_tokens = 200000
  ),
  custom = list(
    name = "Custom",
    base_url = "",
    model = "",
    env_var = NA_character_,
    max_tokens = 16384,
    max_context_tokens = 131072
  ),
  local = list(
    name = "Local (Ollama)",
    base_url = "http://localhost:11434/v1",
    model = "qwen3:0.6b",
    env_var = NA_character_,
    max_tokens = 8192,
    max_context_tokens = 32768
  )
)

#' Auto-detect API key from well-known environment variables
#'
#' Checks provider-specific env vars first, then AGENTICR_API_KEY.
#' Returns list(api_key, base_url, model, provider_name) or NULL.
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
        base_url = preset$base_url,
        model = preset$model,
        provider = key
      ))
    }
  }
  value <- Sys.getenv("AGENTICR_API_KEY", unset = "")
  if (nchar(value) > 0) {
    return(list(
      api_key = value,
      base_url = Sys.getenv("AGENTICR_API_BASE", unset = "https://api.deepseek.com"),
      model = Sys.getenv("AGENTICR_MODEL", unset = "deepseek-v4-pro"),
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
#' 3. Config file: in agenticr's data directory
#' 4. In-session: agentic_config(key = "value")
#'
#' @param ... Named arguments to set (api_key, model, base_url, provider, temperature, max_tokens, reasoning_effort, max_turn_tokens, max_context_tokens)
#' @param save If TRUE, save configuration to agenticr's data directory
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
      if (provider != cfg$provider) {
        if (nchar(preset$base_url) > 0) {
          cfg$base_url <- preset$base_url
        }
        if (nchar(preset$model) > 0) {
          cfg$model <- preset$model
        }
        if (!is.null(preset$max_tokens)) {
          cfg$max_tokens <- preset$max_tokens
        }
      }
      cfg$provider <- provider
      if (!is.null(preset$max_context_tokens)) {
        cfg$max_context_tokens <- preset$max_context_tokens
        agenticr_env$max_context_tokens <- as.integer(preset$max_context_tokens)
      }
      if (!is.null(preset$reasoning_effort)) {
        cfg$reasoning_effort <- preset$reasoning_effort
      } else {
        cfg$reasoning_effort <- NULL
      }
      env_var <- preset$env_var
      if (!is.na(env_var)) {
        key <- Sys.getenv(env_var, unset = "")
        if (nchar(key) > 0) {
          cfg$api_key <- key
        } else {
          cfg$api_key <- ""
        }
      }
      cli::cli_alert_success("Provider set to {preset$name} ({cfg$model})")
    }
  }

  for (name in c("api_key", "model", "base_url", "temperature", "max_tokens",
                  "reasoning_effort", "max_turn_tokens", "max_context_tokens", "provider")) {
    if (!is.null(args[[name]])) {
      cfg[[name]] <- args[[name]]
    }
  }
  # Backward compat: accept old parameter names
  if (!is.null(args$api_base))  cfg$base_url <- args$api_base
  if (!is.null(args$api_model)) cfg$model <- args$api_model

  if (save) {
    save_config(cfg)
  }

  assign("config", cfg, envir = agenticr_env)
  if (!is.null(cfg$max_context_tokens)) {
    agenticr_env$max_context_tokens <- as.integer(cfg$max_context_tokens)
  }
  invisible(cfg)
}

#' Interactive setup wizard
#'
#' Guides user through API key and provider configuration interactively.
#' Walks through provider selection, API key entry, model name, and max tokens.
#'
#' @examples
#' \dontrun{
#' agentic_setup()
#' }
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
        base_url = auto$base_url,
        model = auto$model,
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
  choice_num <- suppressWarnings(as.integer(choice))
  if (is.na(choice_num) || choice_num < 1 || choice_num > length(provider_names)) {
    cli::cli_alert_danger("Invalid choice")
    return(invisible())
  }
  provider <- provider_names[choice_num]
  if (is.na(provider)) {
    cli::cli_alert_danger("Invalid choice")
    return(invisible())
  }

  preset <- PROVIDER_PRESETS[[provider]]
  cli::cli_text("")
  cli::cli_alert_info("Provider: {preset$name}")
  cli::cli_alert_info("Endpoint: {preset$base_url}")

  key_hint <- if (is.na(preset$env_var)) "your-api-key" else paste0("your ", preset$env_var)
  cat(paste0("Enter API key (", key_hint, "): "))
  api_key <- readline()
  if (api_key == "") {
    cli::cli_alert_danger("No API key entered. Setup cancelled.")
    return(invisible())
  }

  model <- readline(paste0("Model [", preset$model, "]: "))
  if (model == "") model <- preset$model

  default_max_tokens <- preset$max_tokens %||% 16384
  max_tokens <- readline(paste0("Max output tokens [", default_max_tokens, "]: "))
  if (max_tokens == "") {
    max_tokens <- default_max_tokens
  } else {
    max_tokens <- as.integer(max_tokens)
  }

  agentic_config(
    api_key = api_key,
    base_url = preset$base_url,
    model = model,
    max_tokens = max_tokens,
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
    base_url = "https://api.deepseek.com",
    model = "deepseek-v4-pro",
    provider = "deepseek",
    temperature = 0.1,
    max_turn_tokens = 64000,
    max_context_tokens = 1048576
  )

  # 1. Config file overrides defaults
  config_file <- file.path(agenticr_dir(), "config.yml")

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
    # Backward compat: map old key names to new
    if (!is.null(file_cfg$api_base) && is.null(file_cfg$base_url)) {
      cfg$base_url <- file_cfg$api_base
    }
    if (!is.null(file_cfg$api_model) && is.null(file_cfg$model)) {
      cfg$model <- file_cfg$api_model
    }
  }

  # 2. Environment variables override config file
  auto <- auto_detect_key()
  if (!is.null(auto)) {
    cfg$api_key <- auto$api_key
    cfg$base_url <- auto$base_url
    cfg$model <- auto$model
    cfg$provider <- auto$provider
  }

  env_key <- Sys.getenv("AGENTICR_API_KEY", unset = "")
  if (nchar(env_key) > 0) {
    cfg$api_key <- env_key
  }
  env_base <- Sys.getenv("AGENTICR_API_BASE", unset = "")
  if (nchar(env_base) > 0) {
    cfg$base_url <- env_base
  }
  env_model <- Sys.getenv("AGENTICR_MODEL", unset = "")
  if (nchar(env_model) > 0) {
    cfg$model <- env_model
  }

  # 3. Apply provider preset defaults for fields not already set
  preset <- PROVIDER_PRESETS[[cfg$provider]]
  if (!is.null(preset)) {
    if (!is.null(preset$reasoning_effort) && is.null(cfg$reasoning_effort)) {
      cfg$reasoning_effort <- preset$reasoning_effort
    }
    if (!is.null(preset$max_tokens) && is.null(cfg$max_tokens)) {
      cfg$max_tokens <- preset$max_tokens
    }
    if (!is.null(preset$max_context_tokens)) {
      cfg$max_context_tokens <- preset$max_context_tokens
    }
  }

  cfg
}

#' Save current config to file
#'
#' @keywords internal
save_config <- function(cfg) {
  config_dir <- agenticr_dir()
  if (!dir.exists(config_dir)) {
    dir.create(config_dir, recursive = TRUE, showWarnings = FALSE)
  }
  config_file <- file.path(config_dir, "config.yml")
  yaml::write_yaml(cfg, config_file)
  if (.Platform$OS.type == "unix") {
    Sys.chmod(config_file, "0600")
    Sys.chmod(config_dir, "0700")
  }
  cli::cli_alert_success("Config saved to {.file {config_file}}")
}

#' Get the current API configuration
#'
#' @keywords internal
get_api_config <- function() {
  cfg <- agenticr_env$config
  if (is.null(cfg)) {
    stop(
      "No configuration loaded. Use agentic_setup() or one of:\n",
      "  agentic_config(api_key = \"sk-...\", save = TRUE)\n",
      "  agentic_config(provider = \"deepseek\")\n",
      "Or set AGENTICR_API_KEY or provider-specific env var."
    )
  }
  # Local and custom providers don't require an API key
  if (cfg$provider == "local" || cfg$provider == "custom") return(cfg)
  if (cfg$api_key == "") {
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
  cli::cli_li("Base URL: {x$base_url}")
  cli::cli_li("Model: {x$model}")
  cli::cli_li("Temperature: {x$temperature}")
  cli::cli_li("Max tokens: {x$max_tokens}")
  if (!is.null(x$reasoning_effort)) {
    cli::cli_li("Reasoning effort: {x$reasoning_effort}")
  }
  cli::cli_li("Max turn tokens: {x$max_turn_tokens}")
  cli::cli_li("Context window: {x$max_context_tokens}")
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
    cli::cli_li("{.val {key}} - {p$name} ({p$model}) [{env}: {key_found}]")
  }
  invisible()
}
