#' LLM API client for AgenticR
#'
#' Communicates with DeepSeek, OpenAI, and other OpenAI-compatible APIs.
#' Supports tool calling and streaming responses.
#'
#' @keywords internal

#' Send a chat completion request
#'
#' @param messages List of message objects
#' @param tools List of tool definitions (optional)
#' @param stream Whether to stream the response
#' @return The parsed API response
#'
#' @keywords internal
chat_completion <- function(messages, tools = NULL, stream = FALSE) {
  cfg <- get_api_config()

  messages <- sanitize_messages(messages)

  body <- list(
    model = cfg$api_model,
    messages = messages,
    temperature = cfg$temperature,
    max_tokens = cfg$max_tokens,
    stream = stream
  )

  if (!is.null(tools) && length(tools) > 0) {
    body$tools <- tools
  }

  url <- paste0(cfg$api_base, "/chat/completions")

  response <- httr::POST(
    url = url,
    httr::add_headers(
      "Authorization" = paste("Bearer", cfg$api_key),
      "Content-Type" = "application/json"
    ),
    body = jsonlite::toJSON(body, auto_unbox = TRUE, force = TRUE),
    encode = "raw",
    httr::timeout(120)
  )

  if (httr::status_code(response) >= 400) {
    error_body <- tryCatch(
      httr::content(response, "text", encoding = "UTF-8"),
      error = function(e) "Unknown error"
    )
    stop("LLM API error (", httr::status_code(response), "): ", error_body)
  }

  content_text <- httr::content(response, "text", encoding = "UTF-8")
  jsonlite::fromJSON(content_text, simplifyVector = FALSE)
}

#' Sanitize messages to ensure valid tool_calls/tool pairing
#'
#' Removes orphaned tool messages that lack a preceding
#' assistant message with tool_calls.
#'
#' @keywords internal
sanitize_messages <- function(messages) {
  if (length(messages) == 0) return(messages)

  clean <- list()
  pending_tool_call_ids <- character(0)

  for (msg in messages) {
    role <- if (is.null(msg$role)) "" else msg$role

    if (role == "assistant" && !is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
      for (tc in msg$tool_calls) {
        if (!is.null(tc$id)) {
          pending_tool_call_ids <- c(pending_tool_call_ids, tc$id)
        }
      }
      clean <- c(clean, list(msg))
    } else if (role == "tool") {
      tc_id <- if (is.null(msg$tool_call_id)) "" else msg$tool_call_id
      if (tc_id %in% pending_tool_call_ids) {
        clean <- c(clean, list(msg))
      }
    } else {
      pending_tool_call_ids <- character(0)
      clean <- c(clean, list(msg))
    }
  }

  clean
}

#' Send a streaming chat completion request
#'
#' @param messages List of message objects
#' @param tools List of tool definitions (optional)
#' @param on_chunk Callback for each content chunk
#' @return The complete assistant message
#'
#' @keywords internal
chat_completion_stream <- function(messages, tools = NULL, on_chunk = function(x) {}) {
  cfg <- get_api_config()

  body <- list(
    model = cfg$api_model,
    messages = messages,
    temperature = cfg$temperature,
    max_tokens = cfg$max_tokens,
    stream = TRUE
  )

  if (!is.null(tools) && length(tools) > 0) {
    body$tools <- tools
  }

  url <- paste0(cfg$api_base, "/chat/completions")

  response <- httr::POST(
    url = url,
    httr::add_headers(
      "Authorization" = paste("Bearer", cfg$api_key),
      "Content-Type" = "application/json",
      "Accept" = "text/event-stream"
    ),
    body = jsonlite::toJSON(body, auto_unbox = TRUE, force = TRUE),
    encode = "raw",
    httr::write_stream(function(x) {
      lines <- strsplit(rawToChar(x), "\n")[[1]]
      for (line in lines) {
        on_chunk(line)
      }
      TRUE
    }),
    httr::timeout(120)
  )

  if (httr::status_code(response) >= 400) {
    stop("LLM API error: ", httr::status_code(response))
  }
}

#' Estimate token count (rough heuristic: 1 token ~ 3.5 chars)
#'
#' @keywords internal
estimate_tokens <- function(messages) {
  total <- 0
  for (msg in messages) {
    if (!is.null(msg$content)) {
      total <- total + nchar(msg$content) / 3.5
    }
    if (!is.null(msg$tool_calls)) {
      total <- total + nchar(jsonlite::toJSON(msg$tool_calls)) / 3.5
    }
  }
  ceiling(total)
}

#' Compact conversation context using a sub-agent LLM call.
#'
#' Sends a summarization request with the SAME context prefix
#' (maximizing cache hit rate), stores the result in the stable summary
#' slot, and trims the conversation to recent turns.
#'
#' @keywords internal
run_compaction <- function(messages) {
  if (length(messages) <= 4) return(messages)

  summary_prompt <- list(list(role = "user", content = paste0(
    "Summarize the conversation so far into a concise context block. ",
    "Include: what the user has been working on, key variables and data, ",
    "important commands/analyses and their results, and any errors encountered. ",
    "Keep it under 300 words."
  )))
  summary_msgs <- c(messages, summary_prompt)
  resp <- tryCatch(
    chat_completion(summary_msgs, tools = NULL),
    error = function(e) NULL
  )
  if (is.null(resp) || length(resp$choices) == 0) return(messages)

  summary_text <- tryCatch(
    resp$choices[[1]]$message$content,
    error = function(e) ""
  )
  if (nchar(trimws(summary_text)) == 0) return(messages)

  agenticr_env$stable_summary <- paste0(
    "[Compaction summary]\n", trimws(summary_text)
  )
  agenticr_env$conversation <- tail(agenticr_env$conversation, 4)

  sys_msg <- messages[[1]]
  new_msgs <- list(sys_msg)

  i <- 2
  while (i <= length(messages)) {
    msg_content <- messages[[i]]$content
    if (!is.null(msg_content) && grepl("^\\[AGENTS\\.md", msg_content)) {
      new_msgs <- c(new_msgs, messages[i])
      i <- i + 1
    } else {
      break
    }
  }

  ctx_msg <- NULL
  if (i <= length(messages) && !is.null(messages[[i]]$content) &&
      grepl("^\\[Stable context\\]", messages[[i]]$content)) {
    ctx_msg <- messages[[i]]
    i <- i + 1
  }
  if (!is.null(ctx_msg)) new_msgs <- c(new_msgs, list(ctx_msg))

  if (i <= length(messages) && !is.null(messages[[i]]$content) &&
      grepl("^\\[Compaction summary\\]", messages[[i]]$content)) {
    i <- i + 1
  }

  new_msgs <- c(new_msgs, list(list(
    role = "user", content = agenticr_env$stable_summary
  )))

  if (length(agenticr_env$conversation) > 0) {
    new_msgs <- c(new_msgs, agenticr_env$conversation)
  }
  new_msgs <- c(new_msgs, list(messages[[length(messages)]]))

  new_msgs
}

#' Extract persistent memory from conversation into MEMORY.md
#'
#' Uses a sub-agent with the SAME context prefix (maximizing cache hit rate)
#' to extract persistent memory from the conversation. Stores result in
#' ~/.agenticr/MEMORY.md. Never extracts discoverable info or file paths.
#'
#' @keywords internal
extract_memory <- function(messages) {
  existing <- ""
  if (file.exists(agenticr_env$memory_file)) {
    existing <- tryCatch(
      paste(readLines(agenticr_env$memory_file, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
  }

  memory_prompt <- paste0(
    "Extract information for a persistent memory file. Write in Markdown ",
    "with these sections:\n\n",
    "## User Profile\n",
    "- Knowledge level, job role, preferred collaboration style\n",
    "- How they like to receive information (concise? detailed?)\n\n",
    "## Reflection & Learnings\n",
    "- What did you learn from this session?\n",
    "- Which approaches worked well?\n",
    "- Which commands or patterns caused errors and their root cause?\n\n",
    "## Environment Learnings\n",
    "- R packages that work (known incompatibilities)\n",
    "- Commands or package functions that caused issues\n\n",
    "## Feedback & Corrections\n",
    "- When the user corrected you, what was the mistake and the fix\n",
    "- WHY the fix is correct -- the underlying principle\n\n",
    "## Project Context\n",
    "- Current project topic, purpose, and goals\n",
    "- Key decisions the user made and WHY\n\n",
    "## Important Files\n",
    "- Only describe what each file CONTAINS and its ROLE, never its path or name\n\n",
    "RULES:\n",
    "- NEVER include file paths, coding style, git history\n",
    "- NEVER repeat information that can be found by searching the repo\n",
    "- Focus on WHY (intent, reasoning) not WHAT (commands, syntax)\n",
    "- If existing memory exists, MERGE new info -- do not duplicate\n",
    "- Keep under 600 words total\n\n"
  )
  if (nchar(existing) > 0) {
    memory_prompt <- paste0(
      memory_prompt,
      "Existing MEMORY.md content to merge with:\n```markdown\n",
      substr(existing, 1, 2000),
      "\n```\n\n"
    )
  }

  summary_msgs <- c(messages, list(list(
    role = "user", content = memory_prompt
  )))
  resp <- tryCatch(
    chat_completion(summary_msgs, tools = NULL),
    error = function(e) NULL
  )
  if (is.null(resp) || length(resp$choices) == 0) return()

  memory <- tryCatch(
    resp$choices[[1]]$message$content,
    error = function(e) ""
  )
  if (nchar(trimws(memory)) == 0) return()

  dir.create(dirname(agenticr_env$memory_file), showWarnings = FALSE, recursive = TRUE)
  writeLines(memory, agenticr_env$memory_file)
  agenticr_env$last_memory_extract_tokens <- agenticr_env$total_session_tokens
}
