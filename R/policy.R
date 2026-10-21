#' Pre-execution permission policy for AgenticR
#'
#' Permission decisions and grants are append-only events. The policy is
#' conservative for model-generated R code and file operations.
#'
#' @keywords internal

agenticr_permission_grants <- function() {
  agenticr_env$permission_grants %||% list()
}

agenticr_normalize_path <- function(path) {
  path <- path.expand(path)
  parent <- dirname(path)
  if (dir.exists(parent)) {
    file.path(normalizePath(parent, mustWork = TRUE), basename(path))
  } else {
    normalizePath(path, mustWork = FALSE)
  }
}

agenticr_grant_matches <- function(grant, action, args = list()) {
  if (is.null(grant) || !is.list(grant)) return(FALSE)
  expires <- grant$expires_at %||% NULL
  if (!is.null(expires)) {
    parsed <- tryCatch(as.POSIXct(expires, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OS%z"),
                       error = function(e) NULL)
    if (!is.null(parsed) && parsed <= Sys.time()) return(FALSE)
  }
  if (!identical(grant$action %||% "*", action)) return(FALSE)
  needle <- grant$contains %||% NULL
  if (!is.null(needle)) {
    text <- args$code %||% args$file_path %||% args$path %||% ""
    if (!grepl(tolower(needle), tolower(text), fixed = TRUE)) return(FALSE)
  }
  prefix <- grant$path_prefix %||% NULL
  if (!is.null(prefix) && !is.null(args$file_path %||% args$path)) {
    path <- agenticr_normalize_path(args$file_path %||% args$path)
    root <- agenticr_normalize_path(prefix)
    if (!(identical(path, root) || startsWith(path, paste0(root, .Platform$file.sep)))) {
      return(FALSE)
    }
  }
  TRUE
}

agenticr_path_scoped <- function(path) {
  if (is.null(path) || !nzchar(path)) return(FALSE)
  resolved <- agenticr_normalize_path(path)
  roots <- unique(vapply(c(getwd(), tempdir(), path.expand("~")),
                         agenticr_normalize_path, character(1)))
  any(vapply(roots, function(root) {
    identical(resolved, root) || startsWith(resolved, paste0(root, .Platform$file.sep))
  }, logical(1)))
}

agenticr_r_code_risk <- function(code) {
  patterns <- c(
    "\\bsystem\\s*\\(",
    "\\bsystem2\\s*\\(",
    "\\bunlink\\s*\\(",
    "file\\.remove\\s*\\(",
    "install\\.packages\\s*\\(",
    "download\\.file\\s*\\(",
    "socketConnection\\s*\\(",
    "eval\\s*\\(\\s*parse"
  )
  any(vapply(patterns, function(p) grepl(p, code, perl = TRUE), logical(1)))
}

agenticr_policy_check <- function(action, args = list(), source = "llm") {
  for (grant in agenticr_permission_grants()) {
    if (agenticr_grant_matches(grant, action, args)) {
      return(list(decision = "allow", reason = "matching permission grant"))
    }
  }

  if (identical(action, "execute_r_code")) {
    code <- args$code %||% ""
    if (identical(source, "user")) {
      return(list(decision = "allow", reason = "explicit user R code"))
    }
    if (grepl("unlink\\s*\\(\\s*['\"]/['\"]", code) ||
        grepl("file\\.remove\\s*\\(\\s*['\"]/['\"]", code)) {
      return(list(decision = "deny", reason = "destructive root path operation"))
    }
    if (agenticr_r_code_risk(code)) {
      return(list(decision = "ask", reason = "R code accesses processes or files"))
    }
    return(list(decision = "allow", reason = "R code is in-process"))
  }

  if (action %in% c("file_write", "file_edit")) {
    path <- args$file_path %||% args$path %||% ""
    if (agenticr_path_scoped(path)) {
      return(list(decision = "allow", reason = "path is inside workspace or temp"))
    }
    return(list(decision = if (identical(source, "user")) "allow" else "ask",
                reason = "path is outside workspace or temp"))
  }

  if (identical(action, "install_package")) {
    return(list(decision = if (identical(source, "user")) "allow" else "ask",
                reason = "package installation"))
  }

  if (startsWith(action, "mcp_")) {
    return(list(decision = if (identical(source, "user")) "allow" else "ask",
                reason = "external MCP action"))
  }

  list(decision = "allow", reason = "read-only or unrestricted tool")
}

agenticr_permission_grant <- function(action, contains = NULL,
                                      path_prefix = NULL, reason = "user approved") {
  grant <- list(
    grant_id = paste0("g_", paste(sample(c(0:9, letters[1:6]), 12, replace = TRUE), collapse = "")),
    action = action,
    reason = reason,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6%z")
  )
  if (!is.null(contains)) grant$contains <- contains
  if (!is.null(path_prefix)) grant$path_prefix <- path_prefix
  agenticr_event_append("permission_grant", list(grant = grant), turn = agenticr_env$turn_counter %||% 0L)
  agenticr_env$permission_grants <- c(agenticr_permission_grants(), list(grant))
  grant
}

agenticr_permission_request <- function(action, args = list(), source = "llm") {
  policy <- agenticr_policy_check(action, args, source)
  agenticr_event_append("policy_decision", list(
    action = action,
    decision = policy$decision,
    reason = policy$reason,
    args = args,
    source = source
  ), turn = agenticr_env$turn_counter %||% 0L)

  if (identical(policy$decision, "allow")) return(TRUE)
  if (identical(policy$decision, "deny")) {
    agenticr_event_append("tool_blocked", list(
      action = action, reason = policy$reason, args = args
    ), turn = agenticr_env$turn_counter %||% 0L)
    return(FALSE)
  }

  answer <- "no"
  if (is.function(agenticr_env$ask_permission_choice)) {
    answer <- agenticr_env$ask_permission_choice(
      paste0(action, ": ", policy$reason)
    )
  } else if (is.function(agenticr_env$ask_permission)) {
    answer <- if (isTRUE(agenticr_env$ask_permission(policy$reason))) "yes" else "no"
  }
  answer <- tolower(trimws(answer %||% "no"))
  approved <- answer %in% c("y", "yes", "ok", "proceed", "allow", "approve",
                            "always", "always allow", "allow always")
  grant <- NULL
  if (answer %in% c("always", "always allow", "allow always")) {
    grant <- agenticr_permission_grant(
      action,
      contains = args$code %||% args$file_path %||% args$path %||% NULL,
      path_prefix = if (action %in% c("file_write", "file_edit"))
        dirname(args$file_path %||% args$path %||% "") else NULL
    )
  }
  agenticr_event_append("approval_result", list(
    action = action,
    approved = approved,
    response = answer,
    grant_id = grant$grant_id %||% NULL
  ), turn = agenticr_env$turn_counter %||% 0L)
  if (!approved) {
    agenticr_event_append("tool_blocked", list(
      action = action, reason = "user denied", args = args
    ), turn = agenticr_env$turn_counter %||% 0L)
  }
  approved
}
