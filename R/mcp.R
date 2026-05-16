#' MCP (Model Context Protocol) client — connects to external tool servers
#' via JSON-RPC over stdio.
#'
#' MCP servers provide additional tools that extend the agent's capabilities.
#' Configure MCP servers in ~/.agenticr/config.yml under the 'mcp' key,
#' or use agentic_install_mcp() / agentic_mcp_add().
#'
#' @keywords internal

#' Create and connect to an MCP server
#'
#' @param name Server name (used as tool prefix)
#' @param command Command to run the MCP server
#' @param args Character vector of command arguments
#' @param env Named list of environment variables
#' @param timeout Connection timeout in seconds
#' @return An MCP server object (environment) or NULL on failure
#'
#' @keywords internal
mcp_connect <- function(name, command, args = character(0), env = list(), timeout = 10) {
  srv <- new.env(parent = emptyenv())
  srv$name <- name
  srv$command <- command
  srv$args <- args
  srv$env <- env
  srv$tools <- list()
  srv$connected <- FALSE
  srv$process <- NULL
  srv$pending <- new.env(parent = emptyenv())
  srv$next_id <- 1L
  srv$lock <- FALSE

  cmd_env <- as.list(Sys.getenv())
  for (n in names(env)) {
    cmd_env[[n]] <- env[[n]]
  }

  srv$process <- tryCatch(
    processx::process$new(
      command = command,
      args = args,
      env = unlist(cmd_env),
      stdin = "|",
      stdout = "|",
      stderr = "|"
    ),
    error = function(e) {
      cli::cli_alert_warning("MCP server '{name}': command '{command}' not found")
      return(NULL)
    }
  )

  if (is.null(srv$process)) return(NULL)

  # Initialize
  result <- mcp_send_request(srv, "initialize", list(
    protocolVersion = "2024-11-05",
    capabilities = list(),
    clientInfo = list(name = "AgenticR", version = "0.1.0")
  ), timeout = timeout)

  if (is.null(result) || !is.null(result$error)) {
    err <- if (is.null(result)) "timeout" else result$error$message
    cli::cli_alert_warning("MCP '{name}' init failed: {err}")
    mcp_disconnect(srv)
    return(NULL)
  }

  # Send initialized notification
  mcp_send_notification(srv, "notifications/initialized", list())

  # Discover tools
  tools_result <- mcp_send_request(srv, "tools/list", list(), timeout = timeout)
  if (is.null(tools_result) || !is.null(tools_result$error)) {
    cli::cli_alert_warning("MCP '{name}' tools/list failed")
    mcp_disconnect(srv)
    return(NULL)
  }

  srv$tools <- tools_result$result$tools %||% list()
  srv$connected <- TRUE
  cli::cli_alert_success("MCP '{name}' connected ({length(srv$tools)} tools)")
  srv
}

#' Send a JSON-RPC request to an MCP server and wait for response
#'
#' @keywords internal
mcp_send_request <- function(srv, method, params, timeout = 10) {
  req_id <- srv$next_id
  srv$next_id <- srv$next_id + 1L
  req <- list(jsonrpc = "2.0", id = req_id, method = method, params = params)
  req_json <- jsonlite::toJSON(req, auto_unbox = TRUE, force = TRUE)

  srv$process$write_input(paste0(req_json, "\n"))

  start <- Sys.time()
  buf <- ""
  while (TRUE) {
    if (!srv$process$is_alive()) {
      return(NULL)
    }
    srv$process$poll_io(100)
    if (srv$process$can_read()) {
      chunk <- srv$process$read_output_lines(1)
      if (length(chunk) == 0) next
      line <- chunk[1]
      response <- tryCatch(
        jsonlite::fromJSON(line, simplifyVector = FALSE),
        error = function(e) NULL
      )
      if (!is.null(response) && identical(response$id, req_id)) {
        return(response)
      }
    }
    if (difftime(Sys.time(), start, units = "secs") > timeout) {
      return(NULL)
    }
  }
}

#' Send a JSON-RPC notification (no response expected)
#'
#' @keywords internal
mcp_send_notification <- function(srv, method, params) {
  notif <- list(jsonrpc = "2.0", method = method, params = params)
  notif_json <- jsonlite::toJSON(notif, auto_unbox = TRUE, force = TRUE)
  srv$process$write_input(paste0(notif_json, "\n"))
}

#' Disconnect an MCP server
#'
#' @keywords internal
mcp_disconnect <- function(srv) {
  srv$connected <- FALSE
  if (!is.null(srv$process)) {
    tryCatch({
      srv$process$kill()
    }, error = function(e) NULL)
    srv$process <- NULL
  }
}

#' Get OpenAI-compatible tool definitions from an MCP server
#'
#' @keywords internal
mcp_tools <- function(srv) {
  result <- list()
  for (t in srv$tools) {
    params <- t$inputSchema %||% list()
    result <- c(result, list(list(
      type = "function",
      "function" = list(
        name = paste0("mcp_", srv$name, "_", t$name),
        description = t$description %||% paste0("MCP tool: ", srv$name, "/", t$name),
        parameters = list(
          type = "object",
          properties = params$properties %||% list()
        )
      )
    )))
  }
  result
}

#' Call a tool on an MCP server
#'
#' @keywords internal
mcp_call_tool <- function(srv, tool_name, arguments) {
  result <- mcp_send_request(srv, "tools/call", list(
    name = tool_name,
    arguments = arguments
  ))
  if (is.null(result)) return(paste0("MCP tool error: timeout"))
  if (!is.null(result$error)) {
    return(paste0("MCP tool error (", srv$name, "/", tool_name, "): ", result$error$message))
  }
  content <- result$result$content %||% list()
  if (is.list(content)) {
    return(paste(sapply(content, function(c) c$text %||% ""), collapse = "\n"))
  }
  as.character(content)
}

# ============================================================================
# MCP Manager — manages multiple MCP server connections
# ============================================================================

agenticr_env$mcp_servers <- list()

#' Connect to all configured MCP servers
#'
#' Reads MCP server config from ~/.agenticr/config.yml or adds manually.
#'
#' @keywords internal
mcp_connect_all <- function() {
  cfg <- agenticr_env$config
  if (is.null(cfg$mcp_servers) || length(cfg$mcp_servers) == 0) return()

  for (name in names(cfg$mcp_servers)) {
    srv_cfg <- cfg$mcp_servers[[name]]
    command <- srv_cfg$command %||% ""
    if (command == "") next
    args <- srv_cfg$args %||% character(0)
    env <- srv_cfg$env %||% list()
    srv <- mcp_connect(name, command, as.character(args), env)
    if (!is.null(srv)) {
      agenticr_env$mcp_servers[[name]] <- srv
    }
  }
}

#' Get all MCP tool definitions (merged from all connected servers)
#'
#' @keywords internal
mcp_all_tools <- function() {
  tools <- list()
  for (srv in agenticr_env$mcp_servers) {
    if (isTRUE(srv$connected)) {
      tools <- c(tools, mcp_tools(srv))
    }
  }
  tools
}

#' Call an MCP tool by full name (mcp_<server>_<tool_name>)
#'
#' @keywords internal
mcp_dispatch <- function(full_name, arguments) {
  if (!startsWith(full_name, "mcp_")) {
    return(paste0("Unknown tool: ", full_name))
  }
  parts <- strsplit(substring(full_name, 5), "_")[[1]]
  if (length(parts) < 2) {
    return(paste0("Invalid MCP tool name: ", full_name))
  }
  server_name <- parts[1]
  tool_name <- paste(parts[-1], collapse = "_")
  srv <- agenticr_env$mcp_servers[[server_name]]
  if (is.null(srv) || !isTRUE(srv$connected)) {
    return(paste0("MCP server '", server_name, "' not connected"))
  }
  mcp_call_tool(srv, tool_name, arguments)
}

#' Disconnect all MCP servers
#'
#' @keywords internal
mcp_disconnect_all <- function() {
  for (name in names(agenticr_env$mcp_servers)) {
    mcp_disconnect(agenticr_env$mcp_servers[[name]])
  }
  agenticr_env$mcp_servers <- list()
}

#' Add an MCP server to the configuration
#'
#' @param name Server name
#' @param command Command to run the MCP server
#' @param args Character vector of command arguments
#' @param env Named list of environment variables
#' @param save If TRUE, save to config file
#' @export
agentic_mcp_add <- function(name, command, args = character(0), env = list(), save = FALSE) {
  cfg <- agenticr_env$config
  if (is.null(cfg$mcp_servers)) cfg$mcp_servers <- list()
  cfg$mcp_servers[[name]] <- list(command = command, args = as.list(args), env = as.list(env))
  assign("config", cfg, envir = agenticr_env)

  srv <- mcp_connect(name, command, as.character(args), env)
  if (!is.null(srv)) {
    agenticr_env$mcp_servers[[name]] <- srv
  }

  if (save) save_config(cfg)
  invisible()
}

#' List connected MCP servers
#'
#' @export
agentic_mcp <- function() {
  if (length(agenticr_env$mcp_servers) == 0) {
    cli::cli_alert_info("No MCP servers connected. Use agentic_mcp_add(name, command) to add one.")
    return(invisible())
  }
  cli::cli_h2("MCP Servers")
  for (name in names(agenticr_env$mcp_servers)) {
    srv <- agenticr_env$mcp_servers[[name]]
    status <- if (isTRUE(srv$connected)) cli::col_green("connected") else cli::col_red("disconnected")
    cli::cli_li("{.val {name}}: {srv$command} ({length(srv$tools)} tools) [{status}]")
  }
  invisible()
}

# ============================================================================
# MCP Tool Executor — routes tool calls to MCP servers
# ============================================================================

#' Execute an MCP tool call from the agent loop (delegates to mcp_dispatch)
#'
#' @keywords internal
mcp_execute_tool <- function(tool_name, arguments) {
  if (!startsWith(tool_name, "mcp_")) {
    return(NULL)
  }
  mcp_dispatch(tool_name, arguments)
}
