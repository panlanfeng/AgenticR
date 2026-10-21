#' Append-only event log for AgenticR sessions
#'
#' `events.jsonl` is the authoritative runtime log. Conversation, task state,
#' permissions and verification are projections rebuilt by replaying it.
#'
#' @keywords internal

agenticr_event_file <- function() {
  if (!is.null(agenticr_env$events_file)) return(agenticr_env$events_file)
  if (is.null(agenticr_env$session_dir)) return(NULL)
  file.path(agenticr_env$session_dir, "events.jsonl")
}

agenticr_event_hash <- function(event) {
  body <- event
  body$hash <- NULL
  json <- jsonlite::toJSON(body, auto_unbox = TRUE, null = "null", force = TRUE)
  digest::digest(json, algo = "sha256", serialize = FALSE)
}

agenticr_event_repair_tail <- function(path, events) {
  if (length(events) == 0) {
    unlink(path)
    return(invisible(NULL))
  }
  lines <- vapply(events, function(event) {
    as.character(jsonlite::toJSON(event, auto_unbox = TRUE, null = "null", force = TRUE))
  }, character(1))
  writeLines(lines, path, useBytes = TRUE)
  invisible(NULL)
}

agenticr_event_read <- function(path = agenticr_event_file(), strict = TRUE) {
  if (is.null(path) || !file.exists(path)) {
    return(list(events = list(), truncated = FALSE, corrupt = FALSE))
  }
  lines <- readLines(path, warn = FALSE)
  events <- list()
  truncated <- FALSE
  for (i in seq_along(lines)) {
    if (!nzchar(trimws(lines[[i]]))) next
    event <- tryCatch(
      jsonlite::fromJSON(lines[[i]], simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(event)) {
      if (i == length(lines)) {
        truncated <- TRUE
        break
      }
      if (strict) stop("event log is corrupt at line ", i, call. = FALSE)
      next
    }
    expected_seq <- length(events) + 1L
    if (!identical(as.integer(event$seq), as.integer(expected_seq))) {
      if (strict) stop("event log has non-contiguous seq at line ", i, call. = FALSE)
      next
    }
    expected_prev <- if (length(events) == 0) "" else events[[length(events)]]$hash
    if (!identical(event$prev_hash %||% "", expected_prev)) {
      if (strict) stop("event log prev_hash mismatch at seq ", event$seq, call. = FALSE)
      next
    }
    actual_hash <- agenticr_event_hash(event)
    if (!identical(event$hash, actual_hash)) {
      if (strict) stop("event log hash mismatch at seq ", event$seq, call. = FALSE)
      next
    }
    events[[length(events) + 1L]] <- event
  }
  list(events = events, truncated = truncated, corrupt = FALSE)
}

agenticr_event_append <- function(type, payload = list(), turn = NULL, round = NULL) {
  path <- agenticr_event_file()
  if (is.null(path)) return(NULL)
  tryCatch({
    read <- agenticr_event_read(path)
    events <- read$events
    if (isTRUE(read$truncated)) {
      agenticr_event_repair_tail(path, events)
    }
    prev <- if (length(events) == 0) "" else events[[length(events)]]$hash
    event <- list(
      seq = length(events) + 1L,
      event_id = paste0(
        format(Sys.time(), "%Y%m%d%H%M%S"), "_",
        paste(sample(c(0:9, letters[1:6]), 12, replace = TRUE), collapse = "")
      ),
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6%z"),
      type = type,
      turn = turn,
      round = round,
      payload = payload,
      prev_hash = prev
    )
    event$hash <- agenticr_event_hash(event)
    line <- as.character(jsonlite::toJSON(event, auto_unbox = TRUE,
                                          null = "null", force = TRUE))
    cat(line, "\n", sep = "", file = path, append = TRUE)
    event
  }, error = function(e) {
    agenticr_env$event_log_degraded <- TRUE
    agenticr_env$last_event_error <- conditionMessage(e)
    cli::cli_alert_danger("Event log write failed: {conditionMessage(e)}")
    NULL
  })
}

agenticr_event_append_message <- function(message, turn = NULL) {
  agenticr_event_append("conversation_message", list(message = message), turn = turn)
}

agenticr_event_replay <- function(events) {
  conversation <- list()
  stable_summary <- NULL
  tasks <- NULL
  task_dependencies <- list()
  permission_grants <- list()
  last_verification <- NULL
  last_turn <- 0L
  for (event in events) {
    type <- event$type %||% ""
    payload <- event$payload %||% list()
    if (identical(type, "conversation_message") && !is.null(payload$message)) {
      conversation <- c(conversation, list(payload$message))
    } else if (identical(type, "compaction")) {
      stable_summary <- payload$summary
      if (!is.null(payload$conversation)) conversation <- payload$conversation
    } else if (identical(type, "task_state")) {
      tasks <- payload$tasks
      task_dependencies <- payload$dependencies %||% list()
    } else if (identical(type, "permission_grant") && !is.null(payload$grant)) {
      if (!any(vapply(permission_grants, function(g) identical(g$grant_id, payload$grant$grant_id), logical(1)))) {
        permission_grants[[length(permission_grants) + 1L]] <- payload$grant
      }
    } else if (identical(type, "permission_revoke")) {
      permission_grants <- Filter(function(g) !identical(g$grant_id, payload$grant_id),
                                  permission_grants)
    } else if (identical(type, "verification")) {
      last_verification <- payload
    } else if (identical(type, "turn_end")) {
      last_turn <- max(last_turn, as.integer(event$turn %||% 0L), na.rm = TRUE)
    }
  }
  list(
    conversation = conversation,
    stable_summary = stable_summary,
    tasks = if (!is.null(tasks) && length(tasks) > 0) {
      do.call(rbind, lapply(tasks, function(task) as.data.frame(task, stringsAsFactors = FALSE)))
    } else tasks,
    task_dependencies = task_dependencies,
    permission_grants = permission_grants,
    last_verification = last_verification,
    turn = last_turn
  )
}

agenticr_event_init <- function(session_dir = agenticr_env$session_dir) {
  if (is.null(session_dir)) return(NULL)
  agenticr_env$events_file <- file.path(session_dir, "events.jsonl")
  agenticr_env$event_log_degraded <- FALSE
  agenticr_env$last_event_error <- NULL
  if (!file.exists(agenticr_env$events_file)) {
    agenticr_event_append("session_start", list(
      session_id = agenticr_env$session_id,
      cwd = getwd(),
      model = agenticr_env$config$model %||% NULL
    ), turn = 0L)
  }
  agenticr_env$events_file
}

agenticr_migrate_turns_to_events <- function(session_dir = agenticr_env$session_dir) {
  turns_file <- file.path(session_dir, "turns.jsonl")
  events_file <- file.path(session_dir, "events.jsonl")
  if (!file.exists(turns_file) || file.exists(events_file)) return(invisible(FALSE))
  agenticr_env$events_file <- events_file
  lines <- readLines(turns_file, warn = FALSE)
  for (line in lines) {
    if (!nzchar(trimws(line))) next
    message <- tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE),
                        error = function(e) NULL)
    if (is.null(message)) next
    content <- message$content %||% ""
    if (grepl("^\\[Compaction summary\\]", content)) {
      agenticr_event_append("compaction", list(
        summary = content,
        conversation = list()
      ), turn = 0L)
    } else {
      agenticr_event_append_message(message, turn = 0L)
    }
  }
  invisible(TRUE)
}
