# Local model support via Ollama
#
# Provides a built-in fallback when no cloud API token is configured.
# Uses Ollama to run Qwen3-0.6B locally with tool-calling support.

# Check if the ollama command is available
local_ollama_bin <- function() {
  Sys.which("ollama")
}

# Check if ollama server is running
local_ollama_alive <- function() {
  tryCatch({
    resp <- httr::GET("http://localhost:11434/api/tags", httr::timeout(2))
    httr::status_code(resp) == 200
  }, error = function(e) FALSE)
}

# Start ollama server in background (only if not already running)
local_ollama_start <- function() {
  if (local_ollama_alive()) {
    cli::cli_alert_info("Ollama server already running on localhost:11434")
    return(TRUE)
  }

  bin <- local_ollama_bin()
  if (!nzchar(bin)) return(FALSE)

  cli::cli_alert_info("Starting Ollama server...")
  agenticr_env$local_server <- tryCatch(
    processx::process$new(
      command = bin,
      args = "serve",
      stdout = "|",
      stderr = "|"
    ),
    error = function(e) {
      cli::cli_alert_danger("Failed to start Ollama: {conditionMessage(e)}")
      NULL
    }
  )

  if (is.null(agenticr_env$local_server)) return(FALSE)

  # Wait for server to be ready (up to 15 seconds)
  for (i in 1:30) {
    Sys.sleep(0.5)
    if (local_ollama_alive()) {
      cli::cli_alert_success("Ollama server ready (localhost:11434)")
      return(TRUE)
    }
  }

  cli::cli_alert_danger("Ollama server did not start in time")
  agenticr_env$local_server$kill()
  agenticr_env$local_server <- NULL
  FALSE
}

# Stop the ollama server we started (only if we own it)
local_ollama_stop <- function() {
  if (!is.null(agenticr_env$local_server)) {
    tryCatch(agenticr_env$local_server$kill(), error = function(e) NULL)
    agenticr_env$local_server <- NULL
  }
}

# Check if a specific model is already pulled
local_model_installed <- function(model) {
  tryCatch({
    resp <- httr::GET("http://localhost:11434/api/tags", httr::timeout(5))
    tags <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"),
                               simplifyVector = FALSE)$models
    any(sapply(tags, function(t) identical(t$name, model)))
  }, error = function(e) FALSE)
}

# Pull the model from Ollama registry
local_model_pull <- function(model) {
  bin <- local_ollama_bin()
  if (!nzchar(bin)) return(FALSE)

  cli::cli_alert_info("Downloading model '{model}' (one-time)...")
  result <- tryCatch(
    system2(bin, c("pull", model), stdout = TRUE, stderr = TRUE),
    error = function(e) {
      cli::cli_alert_danger("Download failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (!is.null(result)) {
    cli::cli_alert_success("Model '{model}' ready")
    return(TRUE)
  }
  FALSE
}

# Detect platform for install instructions
local_platform <- function() {
  os <- Sys.info()[["sysname"]]
  if (os == "Darwin") return("macos")
  if (os == "Linux") return("linux")
  if (os == "Windows") return("windows")
  "other"
}

# Install ollama with platform-specific command
local_ollama_install <- function() {
  plat <- local_platform()
  cmd <- switch(plat,
    macos   = "brew install ollama",
    linux   = "curl -fsSL https://ollama.com/install.sh | sh",
    windows = "winget install Ollama.Ollama",
    NULL
  )
  if (is.null(cmd)) return(FALSE)

  cli::cli_alert_info("Installing Ollama (this may take a few minutes)...")
  cli::cli_text("Running: {.code {cmd}}")
  result <- tryCatch(
    system(cmd, intern = FALSE),
    error = function(e) {
      cli::cli_alert_danger("Install failed: {conditionMessage(e)}")
      NULL
    }
  )
  if (is.null(result) || result != 0) {
    cli::cli_alert_danger("Ollama installation failed. Try manually: {.code {cmd}}")
    return(FALSE)
  }
  cli::cli_alert_success("Ollama installed successfully")
  TRUE
}

# Ensure ollama is running and the model is available
local_ensure <- function(model) {
  if (!local_ollama_start()) {
    has_bin <- nzchar(local_ollama_bin())
    if (has_bin) return(FALSE)

    # Ollama not installed — install it (caller should have confirmed already)
    if (!local_ollama_install()) return(FALSE)
    if (!local_ollama_start()) return(FALSE)
  }

  if (local_model_installed(model)) {
    cli::cli_alert_success("Model '{model}' already installed")
    return(TRUE)
  }

  local_model_pull(model)
}

# Interactive local model setup — called from agentic() when no API token
agentic_local_setup <- function() {
  cli::cli_h1("Local Model Setup")

  model <- "qwen3:1.7b"
  cli::cli_text("Using {.val {model}} via Ollama (~1.4GB download)")
  cli::cli_text("")

  if (!local_ensure(model)) {
    cli::cli_alert_info("Setup cancelled. Run {.code agentic_setup()} to configure a cloud API instead.")
    return(invisible(FALSE))
  }

  cli::cli_text("")
  agentic_config(
    provider = "local",
    base_url = "http://localhost:11434/v1",
    model = model,
    save = TRUE
  )

  cli::cli_alert_success("Local model configured!")
  invisible(TRUE)
}

# Called on exit from agentic() — stop local server if we own it
local_on_exit <- function() {
  local_ollama_stop()
}
