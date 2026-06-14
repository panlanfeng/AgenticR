#!/usr/bin/env Rscript
# Test MCP server install and usage
#
# Run from the repo root: Rscript inst/test-mcp.R

library(jsonlite)
library(cli)
library(yaml)
library(processx)

# Find repo root (parent of inst/)
root <- if (dir.exists("R") && dir.exists("inst")) {
  getwd()
} else if (dir.exists("../R") && dir.exists("../inst")) {
  dirname(getwd())
} else {
  stop("Run from agenticr repo root or inst/ directory")
}

# --- Setup: source package code ---
srcdir <- file.path(root, "R")
source(file.path(srcdir, "agenticr.R"))  # %||%, agenticr_dir, agenticr_env
source(file.path(srcdir, "config.R"))    # load_config, save_config
source(file.path(srcdir, "mcp.R"))        # MCP functions

# .onLoad equivalent
cfg <- load_config()
assign("config", cfg, envir = agenticr_env)

agenticr_env$mcp_servers <- list()

cat("\n=== Test 1: mcp_connect (direct) ===\n")
server_script <- file.path(root, "tests/mcp_echo_server.py")
srv <- mcp_connect("echo", "python3", c(server_script), timeout = 10)

if (is.null(srv)) {
  stop("FAIL: mcp_connect returned NULL")
}
# Register in global server list so dispatch works
agenticr_env$mcp_servers[["echo"]] <- srv
cat(sprintf("Connected: %s, Tools: %d\n", srv$name, length(srv$tools)))
stopifnot(srv$connected == TRUE)
stopifnot(length(srv$tools) == 2)
cat("PASS\n")

cat("\n=== Test 2: mcp_tools (OpenAI format conversion) ===\n")
tools <- mcp_tools(srv)
cat(sprintf("Got %d tool definitions\n", length(tools)))
stopifnot(length(tools) == 2)
# Check first tool has required field
t1 <- tools[[1]]
f1 <- t1[["function"]]
cat(sprintf("Tool 1: %s\n", f1$name))
cat(sprintf("  required: %s\n", if (is.null(f1$parameters$required)) "(none)" else paste(f1$parameters$required, collapse=", ")))
# echo tool has required field
stopifnot("required" %in% names(f1$parameters))
stopifnot("message" %in% f1$parameters$required)

# Check second tool (get_time) has no required field
t2 <- tools[[2]]
f2 <- t2[["function"]]
cat(sprintf("Tool 2: %s\n", f2$name))
cat(sprintf("  required: %s\n", if (is.null(f2$parameters$required)) "(none)" else paste(f2$parameters$required, collapse=", ")))
stopifnot(is.null(f2$parameters$required))
cat("PASS\n")

cat("\n=== Test 3: mcp_call_tool (echo) ===\n")
result <- mcp_call_tool(srv, "echo", list(message = "Hello from R!"))
cat(sprintf("Result: %s\n", result))
stopifnot(grepl("Hello from R!", result))
cat("PASS\n")

cat("\n=== Test 4: mcp_call_tool (get_time) ===\n")
result <- mcp_call_tool(srv, "get_time", list())
cat(sprintf("Result: %s\n", result))
stopifnot(nchar(result) > 0)
cat("PASS\n")

cat("\n=== Test 5: mcp_dispatch ===\n")
result <- mcp_dispatch("mcp_echo_echo", list(message = "dispatch test"))
cat(sprintf("Result: %s\n", result))
if (!grepl("dispatch test", result)) {
  stop(sprintf("FAIL: expected 'dispatch test' in result, got '%s'", result))
}
cat("PASS\n")

cat("\n=== Test 6: mcp_execute_tool ===\n")
result <- mcp_execute_tool("mcp_echo_get_time", list())
cat(sprintf("Result: %s\n", result))
stopifnot(nchar(result) > 0)
cat("PASS\n")

cat("\n=== Test 7: mcp_all_tools (multi-server) ===\n")
all_tools <- mcp_all_tools()
cat(sprintf("All tools from all servers: %d\n", length(all_tools)))
stopifnot(length(all_tools) == 2)
cat("PASS\n")

cat("\n=== Test 8: agentic_mcp() list ===\n")
agentic_mcp()
cat("PASS\n")

cat("\n=== Test 9: agentic_mcp_add ===\n")
# Add another server with save=FALSE
agentic_mcp_add("echo2", "python3", c(server_script), save = FALSE)
cat(sprintf("Servers after add: %s\n", paste(names(agenticr_env$mcp_servers), collapse=", ")))
stopifnot(length(agenticr_env$mcp_servers) == 2)
stopifnot("echo2" %in% names(agenticr_env$mcp_servers))
cat("PASS\n")

cat("\n=== Test 10: mcp_disconnect_all ===\n")
mcp_disconnect_all()
stopifnot(length(agenticr_env$mcp_servers) == 0)
cat("PASS\n")

cat("\n=== ALL TESTS PASSED ===\n")
