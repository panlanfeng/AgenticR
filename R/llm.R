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
    if (nchar(error_body) > 300) error_body <- paste0(substr(error_body, 1, 300), "...")
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
#' Parses SSE stream, calls callbacks for each delta type,
#' and returns the accumulated full response.
#'
#' @param messages List of message objects
#' @param tools List of tool definitions (optional)
#' @param on_reasoning Callback for reasoning_content chunks
#' @param on_content Callback for content chunks
#' @param on_tool_call Callback when a tool call is completed (name, arguments)
#' @return List with content, tool_calls, reasoning_content, usage
#'
#' @keywords internal
chat_completion_stream <- function(messages, tools = NULL,
                                    on_reasoning = function(txt) {},
                                    on_content = function(txt) {},
                                    on_tool_call = function(name, args) {}) {
  cfg <- get_api_config()

  messages <- sanitize_messages(messages)

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

  content_parts <- character(0)
  reasoning_parts <- character(0)
  tool_call_accum <- list()
  usage <- NULL
  has_printed_reasoning <- FALSE
  has_printed_content <- FALSE
  first_chunk <- NULL
  line_buf <- ""

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
      raw_text <- rawToChar(x)
      if (is.null(first_chunk)) first_chunk <<- raw_text
      line_buf <<- paste0(line_buf, raw_text)
      lines <- strsplit(line_buf, "\n")[[1]]
      if (nchar(raw_text) == 0 || substr(raw_text, nchar(raw_text), nchar(raw_text)) != "\n") {
        line_buf <<- lines[length(lines)]
        lines <- lines[-length(lines)]
      } else {
        line_buf <<- ""
      }
      for (line in lines) {
        line <- trimws(line)
        if (line == "" || !startsWith(line, "data: ")) next
        data_str <- substring(line, 7)
        if (data_str == "[DONE]") next

        chunk <- tryCatch(
          jsonlite::fromJSON(data_str, simplifyVector = FALSE),
          error = function(e) NULL
        )
        if (is.null(chunk)) next

        if (!is.null(chunk$usage)) {
          usage <<- chunk$usage
        }

        delta <- chunk$choices[[1]]$delta
        if (is.null(delta)) next

        if (!is.null(delta$reasoning_content) && nchar(delta$reasoning_content) > 0) {
          rc <- delta$reasoning_content
          reasoning_parts <<- c(reasoning_parts, rc)
          if (!has_printed_reasoning) {
            has_printed_reasoning <<- TRUE
            on_reasoning("\n\033[2m")
          }
          on_reasoning(rc)
        }

        if (!is.null(delta$content) && nchar(delta$content) > 0) {
          c <- delta$content
          content_parts <<- c(content_parts, c)
          if (!has_printed_content) {
            has_printed_content <<- TRUE
            if (has_printed_reasoning) {
              on_content("\033[0m\n")
            }
          }
          on_content(c)
        }

        if (!is.null(delta$tool_calls)) {
          for (tc in delta$tool_calls) {
            idx <- tc$index
            if (!is.null(idx)) {
              if (is.null(tool_call_accum[[as.character(idx + 1)]])) {
                tool_call_accum[[as.character(idx + 1)]] <<- list(id = "", name = "", arguments = "")
              }
              entry <- tool_call_accum[[as.character(idx + 1)]]
              if (!is.null(tc$id)) entry$id <- tc$id
              if (!is.null(tc$`function`$name)) entry$name <- paste0(entry$name, tc$`function`$name)
              if (!is.null(tc$`function`$arguments)) entry$arguments <- paste0(entry$arguments, tc$`function`$arguments)
              tool_call_accum[[as.character(idx + 1)]] <<- entry
            }
          }
        }
      }
      TRUE
    }),
    httr::timeout(120)
  )

  if (httr::status_code(response) >= 400) {
    err_text <- tryCatch(
      httr::content(response, "text", encoding = "UTF-8"),
      error = function(e) {
        fc <- first_chunk
        if (is.null(fc)) fc <- "Unknown error"
        trimws(gsub("^data: ", "", fc))
      }
    )
    if (nchar(err_text) > 300) err_text <- substr(err_text, 1, 300)
    stop("LLM API error (", httr::status_code(response), "): ", err_text)
  }

  if (has_printed_reasoning || has_printed_content) {
    on_reasoning("\033[0m")
  }

  content <- paste(content_parts, collapse = "")
  reasoning <- paste(reasoning_parts, collapse = "")

  tool_calls <- list()
  for (entry in tool_call_accum) {
    if (nchar(entry$name) > 0) {
      tool_calls <- c(tool_calls, list(list(
        id = entry$id,
        type = "function",
        "function" = list(name = entry$name, arguments = entry$arguments)
      )))
    }
  }

  list(
    content = content,
    reasoning_content = reasoning,
    tool_calls = tool_calls,
    usage = usage
  )
}

#' Estimate token count (rough heuristic: 1 token ~ 3.5 chars)
#'
#' @keywords internal
estimate_tokens <- function(messages, tools = NULL) {
  total <- 0
  for (msg in messages) {
    total <- total + 4
    if (!is.null(msg$content)) {
      total <- total + nchar(msg$content) / 3.5
    }
    if (!is.null(msg$tool_calls)) {
      total <- total + nchar(jsonlite::toJSON(msg$tool_calls)) / 3.5
    }
    if (!is.null(msg$reasoning_content)) {
      total <- total + nchar(msg$reasoning_content) / 3.5
    }
    if (!is.null(msg$name)) {
      total <- total + nchar(msg$name) / 3.5
    }
  }
  if (!is.null(tools) && length(tools) > 0) {
    tools_json <- jsonlite::toJSON(tools, auto_unbox = TRUE)
    total <- total + nchar(tools_json) / 3.5
  }
  ceiling(total)
}

hard_truncate_messages <- function(messages, conv_start) {
  conv <- messages[conv_start:length(messages)]
  while (length(conv) > 0 && conv[[1]]$role == "tool") conv <- conv[-1]
  keep <- min(16, length(conv))
  conv <- tail(conv, keep)
  last_slot <- messages[[length(messages)]]
  new_msgs <- c(messages[1:min(conv_start - 1, 3)], conv)
  if (last_slot$role == "user" && !identical(conv[[length(conv)]], last_slot)) {
    new_msgs <- c(new_msgs, list(last_slot))
  }
  new_msgs
}

#' Compact conversation context using a sub-agent LLM call.
#'
#' Sends a summarization request with the SAME context prefix
#' (maximizing cache hit rate), stores the result in the stable summary
#' slot, and trims the conversation to recent turns.
#'
#' @keywords internal
run_compaction <- function(messages) {
  if (estimate_tokens(messages) < agenticr_env$max_context_tokens * 0.6) return(messages)

  # Find the start of the conversation tail within messages
  # Skip system, AGENTS.md, skills, stable_context, compaction_summary
  conv_start <- 2
  for (k in 2:min(length(messages), 8)) {
    mc <- messages[[k]]$content
    if (is.null(mc)) next
    if (grepl("^\\[AGENTS\\.md|^\\[Active skill:|^\\[Stable context\\]|^\\[Compaction summary\\]", mc)) {
      conv_start <- k + 1
    } else {
      break
    }
  }

  # Send only system + prefix + last 10 conversation messages to the sub-agent
  tail_start <- max(conv_start, length(messages) - 10)
  summary_messages <- c(messages[1:min(conv_start - 1, 3)], messages[tail_start:length(messages)])

  summary_prompt <- list(list(role = "user", content = paste0(
    "Summarize the conversation so far into a concise context block. ",
    "Include: what the user has been working on, key variables and data, ",
    "important commands/analyses and their results, and any errors encountered. ",
    "Keep it under 300 words."
  )))
  summary_msgs <- c(summary_messages, summary_prompt)
  resp <- tryCatch(
    chat_completion(summary_msgs, tools = NULL),
    error = function(e) NULL
  )
  if (is.null(resp) || length(resp$choices) == 0) {
    return(hard_truncate_messages(messages, conv_start))
  }

  summary_text <- tryCatch(
    resp$choices[[1]]$message$content,
    error = function(e) ""
  )
  if (nchar(trimws(summary_text)) == 0) {
    return(hard_truncate_messages(messages, conv_start))
  }

  agenticr_env$stable_summary <- paste0(
    "[Compaction summary]\n", trimws(summary_text)
  )

  # Trim conversation from the current messages, not stale env state
  conv <- messages[conv_start:length(messages)]
  while (length(conv) > 0 && conv[[1]]$role == "tool") {
    conv <- conv[-1]
  }
  while (estimate_tokens(conv) > 8000 && length(conv) > 4) {
    conv <- conv[-1]
  }

  # Rebuild messages with trimmed conversation
  new_msgs <- messages[1:(conv_start - 1)]
  new_msgs <- c(new_msgs, list(list(
    role = "user", content = agenticr_env$stable_summary
  )))
  if (length(conv) > 0) {
    new_msgs <- c(new_msgs, conv)
  }
  last_slot <- messages[[length(messages)]]
  new_has_last <- length(conv) > 0 && identical(conv[[length(conv)]], last_slot)
  if (last_slot$role == "user" && !new_has_last) {
    new_msgs <- c(new_msgs, list(last_slot))
  }

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
    "Extract the user's preferences and style from this conversation. ",
    "Write in Markdown. Focus only on what the user consistently prefers — ",
    "do NOT include project details, file paths, or session-specific learnings.\n\n",
    "## User Preferences\n",
    "- How does the user like to work? What kind of answers do they prefer?\n",
    "- What packages, syntax, or approaches do they consistently use or prefer?\n",
    "  (e.g. dplyr over data.table, base R over tidyverse, ggplot2 over lattice)\n",
    "- How do they communicate — concise or detailed? Casual or formal?\n",
    "- What is their apparent skill level and domain?\n",
    "- For each preference, explain WHY the user likely prefers it ",
    "(inferred from their choices, corrections, or explicit statements).\n",
    "  Do not just list what they did — explain the underlying preference.\n\n",
    "RULES:\n",
    "- Only general, stable preferences. No one-time requests or temporary needs.\n",
    "- NEVER include file paths, project names, or session-specific details.\n",
    "- If existing memory exists, MERGE — do not duplicate. Update outdated preferences.\n",
    "- Keep under 300 words total.\n\n"
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
