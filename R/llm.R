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

#' Estimate token count (rough heuristic: 1 token ≈ 3.5 chars)
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
  ctx_msg <- NULL
  i <- 2
  if (length(messages) > 1 && !is.null(messages[[2]]$content) &&
      grepl("^\\[Stable context\\]", messages[[2]]$content)) {
    ctx_msg <- messages[[2]]
    i <- 3
  }
  sum_msg <- NULL
  if (i <= length(messages) && !is.null(messages[[i]]$content) &&
      grepl("^\\[Compaction summary\\]", messages[[i]]$content)) {
    i <- i + 1
  }

  last_msg <- messages[[length(messages)]]

  new_msgs <- list(sys_msg)
  if (!is.null(ctx_msg)) new_msgs <- c(new_msgs, list(ctx_msg))
  new_msgs <- c(new_msgs, list(list(
    role = "user", content = agenticr_env$stable_summary
  )))
  if (length(agenticr_env$conversation) > 0) {
    new_msgs <- c(new_msgs, agenticr_env$conversation)
  }
  new_msgs <- c(new_msgs, list(last_msg))

  new_msgs
}
