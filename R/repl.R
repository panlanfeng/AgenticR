#' Start an AgenticR session
#'
#' Opens an interactive AI-assisted R session. Type natural language or R code
#' at the prompt. Natural language is routed to an LLM agent that generates and
#' executes R code. Normal R code is executed directly.
#'
#' Use Ctrl+C or type exit() to quit the agentic session. Conversation history
#' is maintained between turns for context-aware assistance.
#'
#' @param auto If TRUE (default), tries to auto-configure from environment.
#'        Set to FALSE to always show configuration prompt.
#' @param ... Not used
#' @export
agentic <- function(auto = TRUE, ...) {
  if (agenticr_env$is_active) {
    agenticr_env$is_active <- FALSE
  }

  agenticr_env$is_active <- TRUE
  agenticr_env$conversation <- list()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$last_known_cwd <- getwd()
  agenticr_env$session_start <- Sys.time()
  agenticr_env$last_memory_extract_tokens <- 0L
  agenticr_env$total_session_tokens <- 0L
  agenticr_env$active_skills <- list()
  agenticr_env$files_read <- list()
  agenticr_env$session_id <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                                     paste(sample(c(0:9, letters[1:6]), 8, replace = TRUE), collapse = ""))
  agenticr_env$session_dir <- file.path(
    Sys.getenv("HOME", unset = "~"), ".agenticr", "sessions", agenticr_env$session_id)
  dir.create(agenticr_env$session_dir, showWarnings = FALSE, recursive = TRUE)
  agenticr_env$outputs_dir <- file.path(agenticr_env$session_dir, "outputs")
  dir.create(agenticr_env$outputs_dir, showWarnings = FALSE, recursive = TRUE)
  agenticr_env$history_file <- file.path(agenticr_env$session_dir, "history.jsonl")
  agenticr_env$turns_file <- file.path(agenticr_env$session_dir, "turns.jsonl")
  agenticr_env$turn_counter <- 0L
  agenticr_env$saved_msg_count <- 0L
  agenticr_env$ask_permission <- function(prompt) {
    cli::cli_alert_warning(paste0("Permission required: ", prompt))
    ans <- readline("Proceed? [y/N] ")
    tolower(trimws(ans)) %in% c("y", "yes")
  }

  on.exit({
    agenticr_env$is_active <- FALSE
    agenticr_env$conversation <- list()
    mcp_disconnect_all()
  })

  cli::cli_h1("AgenticR - AI-Powered R Console")
  cli::cli_text("Type natural language or R code.")
  cli::cli_text("Type {.code exit()} or press {.kbd Ctrl+C} to quit.")
  cli::cli_text("Type {.code /help} for assistance.")
  load_r_history()
  enable_tab_completion()

  cfg <- tryCatch(get_api_config(), error = function(e) {
    cli::cli_alert_danger("{.val {e$message}}")
    cli::cli_text("")
    cli::cli_text("Set up your API key now:")
    cli::cli_text("  {.code agentic_config(api_key = \"sk-...\", save = TRUE)}")
    cat("\nEnter your API key (or press Enter to exit): ")
    key <- readline()
    if (key == "") return(invisible())
    agentic_config(api_key = key, save = TRUE)
    cli::cli_text("")
    cfg2 <- tryCatch(get_api_config(), error = function(e2) {
      cli::cli_alert_danger("Still no valid key. Exiting.")
      NULL
    })
    if (is.null(cfg2)) return(invisible())
    cfg2
  })
  if (is.null(cfg)) return(invisible())

  cli::cli_text("{.emph {cfg$api_model}} @ {.url {cfg$api_base}}")
  cli::cli_text("Session: {.file {agenticr_env$session_dir}}")

  mcp_connect_all()

  while (TRUE) {
    input <- tryCatch(
      readline(prompt = cli::col_blue("agent> ")),
      interrupt = function(e) {
        cat("\033[0m\n")
        return(NULL)
      }
    )

    if (is.null(input)) break

    input <- trimws(input)
    if (input %in% c("exit()", "quit()", "exit", "quit", "q")) break
    if (input == "") next

    if (grepl("^/", input)) {
      handle_slash_command(input)
      next
    }

    input <- read_complete_input(input)

    cat("\033[90m", "Thinking...", "\033[0m\r", sep = "")
    utils::flush.console()

    result <- tryCatch(
      process_input(input),
      interrupt = function(e) {
        cat("\033[0m")
        cli::cli_alert_warning("Interrupted.")
        NULL
      },
      error = function(e) {
        cat("\033[0m")
        cli::cli_alert_danger("Error: {.val {conditionMessage(e)}}")
        utils::flush.console()
        NULL
      }
    )

    write_turn_history(input, result)

    utils::flush.console()
  }

  cli::cli_text("")
  cli::cli_alert_info("Exiting. Session saved to {.file {agenticr_env$session_dir}}")
  cli::cli_text("Conversation: {.file {agenticr_env$turns_file}}")
  cli::cli_text("Resume with: {.code agentic_resume(\"{agenticr_env$session_id}\")}")
  invisible()
}

#' Read complete R input, handling multi-line expressions
#'
#' If the input is an incomplete R expression (e.g. ends with |>, %>%, +),
#' reads continuation lines until the expression is complete.
#' Non-R (natural language) input is returned as-is.
#'
#' @keywords internal
read_complete_input <- function(first_line) {
  parsed <- tryCatch(parse(text = first_line), error = function(e) e)

  if (!inherits(parsed, "error")) return(first_line)

  err_msg <- conditionMessage(parsed)

  # "unexpected end of input" → genuinely incomplete → continue
  is_incomplete <- grepl("unexpected end of input|unexpected end of line",
                         err_msg, ignore.case = TRUE)

  # If input is natural language, return immediately — don't enter multiline
  if (is_incomplete && is_natural_language(first_line)) {
    return(first_line)
  }

  # "INCOMPLETE_STRING" → apostrophe (NL) or unclosed R string (code)
  if (!is_incomplete && grepl("INCOMPLETE_STRING", err_msg, ignore.case = TRUE)) {
    if (!is_natural_language(first_line)) {
      is_incomplete <- TRUE
    } else {
      return(first_line)
    }
  }

  if (!is_incomplete) return(first_line)

  lines <- first_line
  while (TRUE) {
    next_line <- tryCatch(
      readline(prompt = "+ "),
      interrupt = function(e) {
        cat("\n")
        return(NULL)
      }
    )

    if (is.null(next_line)) break
    next_line <- trimws(next_line)
    if (next_line == "") {
      # Blank line: only break if accumulated code already parses
      parsed <- tryCatch(parse(text = lines), error = function(e) e)
      if (!inherits(parsed, "error")) break
      next
    }

    lines <- paste(lines, next_line, sep = "\n")

    parsed <- tryCatch(parse(text = lines), error = function(e) e)
    if (!inherits(parsed, "error")) break

    err_msg <- conditionMessage(parsed)
    is_incomplete <- grepl("unexpected end of input|unexpected end of line",
                           err_msg, ignore.case = TRUE)
    if (!is_incomplete) break
  }

  lines
}

#' Process user input: detect NL vs R and route accordingly
#'
#' @keywords internal
process_input <- function(input) {
  is_nl <- is_natural_language(input)

  if (!is_nl) {
    result <- tryCatch({
      con <- textConnection("output_lines", open = "w", local = TRUE)
      sink(con, type = "output")
      sink(con, type = "message")

      expr <- parse(text = input)
      if (length(expr) == 0) {
        sink(type = "message")
        sink(type = "output")
        close(con)
        return(list(nl = FALSE, output = ""))
      }
      result <- withVisible(eval(expr, envir = .GlobalEnv))

      sink(type = "message")
      sink(type = "output")
      close(con)

      out_lines <- output_lines
      if (result$visible) {
        result_str <- utils::capture.output(print(result$value))
        out_lines <- c(out_lines, result_str)
      }

      output <- paste(out_lines, collapse = "\n")
      if (nchar(trimws(output)) > 0) {
        cat(output, "\n")
        utils::flush.console()
      }

      conv_msg <- paste0("[R code executed]\n", input)
      if (nchar(trimws(output)) > 0) {
        conv_msg <- paste0(conv_msg, "\n\nOutput:\n", output)
      }
      agenticr_env$conversation <- c(
        agenticr_env$conversation,
        list(list(role = "user", content = conv_msg))
      )
      write_r_history(input)

      list(nl = FALSE, output = output)
    }, error = function(e) {
      tryCatch({
        sink(type = "message")
        sink(type = "output")
        close(con)
      }, error = function(x) NULL)
      error_msg <- conditionMessage(e)
      if (grepl("could not find function", error_msg) ||
          grepl("there is no package called", error_msg) ||
          grepl("^unexpected (symbol|end of input|')'|','|'}'|string)", error_msg) ||
          grepl("object .* not found", error_msg)) {
        process_with_agent(input)
        return(list(nl = TRUE, response = tail(agenticr_env$conversation, 1)[[1]]$content %||% ""))
      }
      cli::cli_alert_danger("{.val {error_msg}}")
      list(nl = FALSE, output = "", error = error_msg)
    })

    return(result)
  }

  process_with_agent(input)
  list(nl = TRUE, response = tail(agenticr_env$conversation, 1)[[1]]$content %||% "")
}

#' Save conversation messages to turns JSONL file (append-only)
#'
#' Appends each message as a JSON line. Tool results that were saved to
#' external files by truncate_tool_result already contain the file reference
#' in their content field.
#'
#' @keywords internal
save_turns_jsonl <- function(messages, start_idx) {
  if (is.null(agenticr_env$turns_file)) return()
  n <- length(messages)
  if (start_idx > n) return()

  lines <- character(n - start_idx + 1)
  for (i in start_idx:n) {
    msg <- messages[[i]]
    lines[i - start_idx + 1] <- tryCatch(
      jsonlite::toJSON(msg, auto_unbox = TRUE, force = TRUE, null = "null"),
      error = function(e) "{}"
    )
  }
  cat(paste(lines, collapse = "\n"), "\n", sep = "",
      file = agenticr_env$turns_file, append = TRUE)
}

#' Process natural language input through the LLM agent
#'
#' @keywords internal
process_with_agent <- function(user_input) {
  if (is.null(agenticr_env$session_dir)) {
    agenticr_env$session_dir <- file.path(tempdir(), "agenticr_session")
    agenticr_env$outputs_dir <- file.path(agenticr_env$session_dir, "outputs")
    dir.create(agenticr_env$outputs_dir, showWarnings = FALSE, recursive = TRUE)
    agenticr_env$session_id <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
                                       paste(sample(c(0:9, letters[1:6]), 8, replace = TRUE), collapse = ""))
  }
  cfg <- get_api_config()
  tools <- get_tool_definitions()
  mcp_tools <- mcp_all_tools()
  if (length(mcp_tools) > 0) {
    tools <- c(tools, mcp_tools)
  }

  messages <- list(list(role = "system", content = SYSTEM_PROMPT))

  if (!agenticr_env$context_injected) {
    agenticr_env$context_injected <- TRUE
    agents_md <- load_agents_md()
    if (nchar(agents_md) > 0) {
      messages <- c(messages, list(list(
        role = "user",
        content = paste0("[AGENTS.md -- user instructions]\n", agents_md)
      )))
    }
    active <- get_active_skill_prompts()
    if (nchar(active) > 0) {
      messages <- c(messages, list(list(
        role = "user",
        content = active
      )))
    }
    messages <- c(messages, list(list(
      role = "user",
      content = build_stable_context()
    )))
  }

  if (!is.null(agenticr_env$stable_summary)) {
    messages <- c(messages, list(list(
      role = "user",
      content = agenticr_env$stable_summary
    )))
  }

  if (length(agenticr_env$conversation) > 0) {
    messages <- c(messages, agenticr_env$conversation)
  }

  user_content <- user_input
  cwd <- getwd()
  if (cwd != agenticr_env$last_known_cwd) {
    agenticr_env$last_known_cwd <- cwd
    user_content <- paste0(
      "<system_reminder>\nWorking directory changed to: ", cwd,
      "\n</system_reminder>\n\n", user_content
    )
  }
  messages <- c(messages, list(list(role = "user", content = user_content)))

  for (round in 1:cfg$max_rounds) {
    token_count <- estimate_tokens(messages, tools)
    if (token_count > agenticr_env$max_context_tokens * 0.8) {
      messages <- run_compaction(messages)
    }

    agenticr_env$total_session_tokens <- estimate_tokens(messages, tools)
    since_last <- token_count - agenticr_env$last_memory_extract_tokens
    if (since_last > 50000) {
      extract_memory(messages)
    }

    stream_result <- NULL
    for (retry in 1:3) {
      stream_result <- tryCatch(
        chat_completion_stream(
          messages, tools,
          on_reasoning = function(txt) {
            cat(txt, sep = "")
            utils::flush.console()
          },
          on_content = function(txt) {
            cat(txt, sep = "")
            utils::flush.console()
          },
          on_tool_call = function(name, args) {}
        ),
        error = function(e) {
          cli::cli_alert_warning("API error (attempt {retry}/3): {.val {conditionMessage(e)}}")
          NULL
        }
      )
      if (!is.null(stream_result)) break
      if (retry < 3) Sys.sleep(min(2^retry, 10))
    }

    if (is.null(stream_result)) {
      cat("\033[0m")
      cli::cli_alert_danger("LLM API call failed after 3 attempts.")
      cli::cli_alert_info("Conversation state preserved. You can continue or retry.")
      break
    }

    content <- stream_result$content
    reasoning <- stream_result$reasoning_content
    tool_calls <- stream_result$tool_calls

    if (nchar(content) > 0 || nchar(reasoning) > 0) {
      cat("\033[0m\n")
      utils::flush.console()
    }

    if (length(tool_calls) > 0) {
      tool_names <- sapply(tool_calls, function(tc) tc$`function`$name)
      cat(cli::col_silver(paste0("[", paste(tool_names, collapse = ", "), "]\n")))
      utils::flush.console()

      assistant_msg <- list(
        role = "assistant",
        tool_calls = tool_calls
      )
      if (nchar(content) > 0) {
        assistant_msg$content <- content
      }
      if (nchar(reasoning) > 0) {
        assistant_msg$reasoning_content <- reasoning
      }
      messages <- c(messages, list(assistant_msg))

      for (tc in tool_calls) {
        tool_name <- tc$`function`$name
        tool_args <- list()
        json_err <- NULL
        tool_args <- tryCatch(
          jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE),
          error = function(e) { json_err <<- conditionMessage(e); list() }
        )

        if (!is.null(json_err)) {
          tool_result <- paste0(
            "TOOL ARGUMENT JSON PARSE ERROR. Fix the JSON syntax and retry.\n",
            "Parse error: ", json_err, "\n",
            "Raw arguments received: ", tc$`function`$arguments
          )
        } else {
          tool_result <- execute_tool(tool_name, tool_args)
        }

        if (tool_name %in% c("execute_r_code", "file_edit") &&
            !is.null(tool_result) && nchar(trimws(tool_result)) > 0) {
          cat(tool_result, "\n")
          utils::flush.console()
        }

        messages <- c(messages, list(list(
          role = "tool",
          tool_call_id = tc$id,
          content = if (is.null(tool_result)) "" else tool_result
        )))
      }

      next
    }

    if (nchar(content) > 0) {
      code_blocks <- extract_r_code_blocks(content)

      if (length(code_blocks) > 0) {
        text_only <- remove_r_code_blocks(content)
        if (nchar(trimws(text_only)) > 0) {
          cat(text_only, "\n")
          utils::flush.console()
        }
      }

      msg_entry <- list(
        role = "assistant",
        content = content
      )
      if (nchar(reasoning) > 0) {
        msg_entry$reasoning_content <- reasoning
      }
      messages <- c(messages, list(msg_entry))

      if (length(code_blocks) > 0) {
        for (code in code_blocks) {
          tool_result <- tool_execute_r_code(code)
          messages <- c(messages, list(list(
            role = "user",
            content = paste0(
              "[R code executed]\n", code,
              if (nchar(trimws(tool_result)) > 0)
                paste0("\n\nOutput:\n", tool_result)
              else ""
            )
          )))
        }
        next
      }

      cat("\n")
      break
    }

    cli::cli_alert_warning("Agent returned an empty response. Try rephrasing your query.")
    break
  }

  conv <- messages[sapply(messages, function(m) {
    m$role != "system" &&
    !grepl("^\\[Compaction summary\\]", m$content %||% "")
  })]
  conv <- sanitize_messages(conv)

  agenticr_env$conversation <- conv

  new_start <- agenticr_env$saved_msg_count + 1L
  if (new_start <= length(conv)) {
    save_turns_jsonl(conv, new_start)
    agenticr_env$saved_msg_count <- length(conv)
  }

  utils::flush.console()
}

#' Write a turn to the session history file
#'
#' @keywords internal
#' Load R command history for up-arrow recall
#'
#' @keywords internal
load_r_history <- function() {
  if (!is.null(agenticr_env$r_history_file) && file.exists(agenticr_env$r_history_file)) {
    tryCatch(
      suppressWarnings(utils::loadhistory(agenticr_env$r_history_file)),
      error = function(e) NULL
    )
  }
}

#' Enable tab completion in the readline REPL
#'
#' @keywords internal
enable_tab_completion <- function() {
  rc.settings(ipck = TRUE, files = TRUE, func = TRUE, args = TRUE)
}
write_r_history <- function(code) {
  if (is.null(agenticr_env$r_history_file)) return()
  dir.create(dirname(agenticr_env$r_history_file), showWarnings = FALSE, recursive = TRUE)
  cat(paste0(code, "\n"), file = agenticr_env$r_history_file, append = TRUE)
  # Reload so up-arrow finds newly written commands immediately
  tryCatch(
    suppressWarnings(utils::loadhistory(agenticr_env$r_history_file)),
    error = function(e) NULL
  )
}

write_turn_history <- function(user_input, result) {
  if (is.null(agenticr_env$history_file)) return()
  agenticr_env$turn_counter <- agenticr_env$turn_counter + 1L

  turn_type <- if (is.null(result)) "unknown" else if (isTRUE(result$nl)) "nl" else "r"

  record <- list(
    turn = agenticr_env$turn_counter,
    timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    type = turn_type,
    input = substr(user_input, 1, 500)
  )

  if (turn_type == "r") {
    if (!is.null(result$output) && nchar(trimws(result$output)) > 0) {
      record$output <- substr(result$output, 1, 2000)
    }
    if (!is.null(result$error)) {
      record$error <- result$error
    }
  } else if (turn_type == "nl") {
    if (!is.null(result$response) && nchar(result$response) > 0) {
      record$response <- substr(result$response, 1, 2000)
    }
  }

  line <- tryCatch(
    jsonlite::toJSON(record, auto_unbox = TRUE, force = TRUE),
    error = function(e) "{}"
  )

  cat(line, "\n", file = agenticr_env$history_file, append = TRUE)
}

#' Show recent session history
#'
#' @keywords internal
show_history <- function() {
  if (is.null(agenticr_env$history_file) || !file.exists(agenticr_env$history_file)) {
    cli::cli_alert_info("No history yet. Start a conversation first.")
    return(invisible())
  }
  lines <- tryCatch(
    readLines(agenticr_env$history_file, warn = FALSE),
    error = function(e) character(0)
  )
  if (length(lines) == 0) {
    cli::cli_alert_info("History is empty.")
    return(invisible())
  }
  cli::cli_h2("Session History")
  recent <- tail(lines, 10)
  for (line in recent) {
    entry <- tryCatch(
      jsonlite::fromJSON(line, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (is.null(entry)) next
    inp <- entry$input %||% ""
    if (nchar(inp) > 80) inp <- paste0(substr(inp, 1, 80), "...")
    cli::cli_li("#{entry$turn} {.val {inp}}")
  }
  cli::cli_text("Full history: {.file {agenticr_env$history_file}}")
  invisible()
}

SYSTEM_PROMPT <- paste0(
  "You are a coding agent in an interactive R console. ",
  "You help users with general coding, statistical analysis, data transformation, ",
  "and visualization by understanding their intent and which step the user is currently in.\n\n",

  "Your task:\n",
  "- When user inputs are incorrect R code, fix the errors and execute ",
  "the corrected code. It is expected that users enter commands ",
  "with broken grammar or typos. Do not explain errors.\n",
  "- When user describes what they want in natural language, translate ",
  "their intent into R code and execute it via tools.\n",
  "- When user asks a complex task, break it down and achieve it step by step using tools.\n",
  "- When user asks a general question, ",
  "answer it using available tools if needed.\n\n",

  "Output expectations:\n",
  "- Be short and concise. Focus on actions and results.\n",
  "- Be direct, no headers or sections.\n",
  "- Avoid unnecessary intermediate outputs.\n",
  "- DO NOT send R code and output in your text response. User sees the ",
  "executed code and results directly in the REPL. Do not repeat them.\n",
  "- Do not output full file contents in your response -- use read_file and file_edit tools instead.\n",
  "- Do not add comments in the R code.\n",
  "- Only do End-of-turn summary if the user explicitly requests it.\n",
  "- Do not repeat the user request.\n\n",


  "Ask for user permission before:\n",
  "- deleting files or data\n\n",

  "When code fails with \"could not find function\", \"there is no package\", ",
  "\"object not found\", or similar:\n",
  "- First check if it is a typo or genuine missing dependency by reviewing ",
  "conversation history and the environment.\n",
  "- If a package is needed, request installation via tool.\n",
  "- If user declines, propose a built-in alternative.\n\n",

  "R documentation and help:\n",
  "- Use the get_function_help tool to look up R function documentation. ",
  "NEVER use help(), ?, or help.search() directly in execute_r_code — ",
  "they open interactive pagers that block the session.\n",
  "- When user asks to find functions by topic, use your own knowledge ",
  "of base R and common packages. Do not use help.search()."
)

#' Load AGENTS.md from global and project directories
#'
#' @keywords internal
load_agents_md <- function() {
  blocks <- character(0)
  global_path <- file.path(
    Sys.getenv("HOME", unset = "~"),
    ".agenticr",
    "AGENTS.md"
  )
  if (file.exists(global_path)) {
    content <- tryCatch(
      paste(readLines(global_path, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    if (nchar(trimws(content)) > 0) {
      blocks <- c(blocks, paste0("[global]\n", content))
    }
  }
  cwd_path <- file.path(getwd(), "AGENTS.md")
  if (file.exists(cwd_path)) {
    content <- tryCatch(
      paste(readLines(cwd_path, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    if (nchar(trimws(content)) > 0) {
      blocks <- c(blocks, paste0("[project]\n", content))
    }
  }
  paste(blocks, collapse = "\n\n")
}

#' Build the stable context block (injected once, never changes)
#'
#' @keywords internal
build_stable_context <- function() {
  mem_note <- ""
  if (file.exists(agenticr_env$memory_file)) {
    mem_note <- paste0(
      "\nMemory: use read_file to load ", agenticr_env$memory_file,
      " -- contains user profile, environment learnings, past corrections"
    )
  }
  paste0(
    "[Stable context]\n",
    "R version: ", R.version.string, "\n",
    "Platform: ", R.version$platform, "\n",
    "Start time: ", format(agenticr_env$session_start, "%Y-%m-%d %H:%M:%S"), "\n",
    "Working directory at start: ", getwd(),
    mem_note
  )
}

#' Extract R code blocks from markdown text
#'
#' Supports \verb{```{r}...```} and \verb{```...```} blocks
#'
#' @keywords internal
extract_r_code_blocks <- function(text) {
  pattern <- "(?s)```\\s*(?:r|\\{[rR][^}]*\\})\\s*\\n?(.*?)```"
  matches <- gregexpr(pattern, text, perl = TRUE)[[1]]
  if (length(matches) == 0 || matches[1] == -1) return(character(0))

  codes <- character(0)
  capture_start <- attr(matches, "capture.start")
  capture_len <- attr(matches, "capture.length")
  for (i in seq_along(matches)) {
    start <- capture_start[i, 1]
    len <- capture_len[i, 1]
    if (is.na(start) || len <= 0) next
    code <- substr(text, start, start + len - 1)
    code <- trimws(code)
    if (nchar(code) > 0) {
      codes <- c(codes, code)
    }
  }

  codes
}

#' Remove R code blocks from text, leaving only explanatory text
#'
#' @keywords internal
remove_r_code_blocks <- function(text) {
  text <- gsub("(?s)```\\s*(?:r|\\{[Rr]\\})?\\s*\\n?.*?```", "", text, perl = TRUE)
  text <- gsub("(?s)```[^`]*?```", "", text, perl = TRUE)
  trimws(text)
}

#' Handle slash commands in the REPL
#'
#' @keywords internal
handle_slash_command <- function(input) {
  switch(
    input,
    "/help" = {
      cli::cli_h2("AgenticR Commands")
      cli::cli_li("{.code /help} - Show this help")
      cli::cli_li("{.code /config} - Show current configuration")
      cli::cli_li("{.code /clear} - Clear conversation history")
      cli::cli_li("{.code /vars} - List variables in global environment")
      cli::cli_li("{.code /info <name>} - Show info about a variable")
      cli::cli_li("{.code /skills} - List installed skills")
      cli::cli_li("{.code /skill <name>} - Activate a skill")
      cli::cli_li("{.code /skill:off <name>} - Deactivate a skill")
      cli::cli_li("{.code /mcp} - List MCP servers")
      cli::cli_li("{.code /history} - View recent session history")
      cli::cli_li("{.code exit()} or {.kbd Ctrl+C} - Exit agentic session")
    },
    "/skills" = agentic_skills(),
    "/mcp" = agentic_mcp(),
    "/history" = show_history(),
    "/config" = {
      cfg <- get_api_config()
      print.agenticr_config(cfg)
    },
    "/clear" = {
      ans <- readline("Clear all conversation history? This cannot be undone. [y/N] ")
      if (tolower(trimws(ans)) %in% c("y", "yes")) {
        agenticr_env$conversation <- list()
        cli::cli_alert_success("Conversation history cleared.")
      } else {
        cli::cli_alert_info("Cancelled.")
      }
    },
    "/vars" = {
      cat(tool_search_variables(".*"), "\n")
    },
    {
      if (grepl("^/skill:off\\s", input)) {
        skill_name <- trimws(sub("^/skill:off\\s+", "", input))
        agenticr_env$active_skills[[skill_name]] <- NULL
        cli::cli_alert_success("Skill '{skill_name}' deactivated.")
      } else if (grepl("^/skill\\s", input)) {
        skill_name <- trimws(sub("^/skill\\s+", "", input))
        all_skills <- load_skills()
        if (is.null(all_skills[[skill_name]])) {
          cli::cli_alert_warning("Skill '{skill_name}' not installed. Use agentic_install_skill() to add it.")
        } else {
          agenticr_env$active_skills[[skill_name]] <- TRUE
          cli::cli_alert_success("Skill '{skill_name}' activated for this session.")
        }
      } else if (grepl("^/info\\s", input)) {
        var_name <- trimws(sub("^/info\\s+", "", input))
        cat(tool_get_dataframe_info(var_name), "\n")
      } else {
        cli::cli_alert_warning("Unknown command: {input}. Type /help for help.")
      }
    }
  )
}

#' Process a single natural language query (non-interactive)
#'
#' @param query The natural language query to process
#' @return Invisibly returns the conversation messages
#' @export
agentic_process <- function(query) {
  if (is.null(query) || nchar(trimws(query)) == 0) {
    stop("query must be a non-empty string")
  }

  agenticr_env$ask_permission <- function(prompt) {
    cli::cli_alert_warning(paste0("Permission required: ", prompt))
    ans <- readline("Proceed? [y/N] ")
    tolower(trimws(ans)) %in% c("y", "yes")
  }

  process_with_agent(query)
  invisible(agenticr_env$conversation)
}

#' Chat with the agent (maintains conversation history)
#'
#' @param query The natural language query
#' @return Invisibly returns the conversation messages
#' @export
agentic_chat <- function(query) {
  agentic_process(query)
}

#' Enable error interceptor for standard R console
#'
#' When enabled, agenticr sets a global error handler that detects
#' natural language inputs that caused errors and processes them
#' with the LLM agent automatically.
#'
#' @param auto_process If TRUE (default), automatically processes NL-like
#'        errors with the LLM agent. If FALSE, just suggests using agenticr.
#' @export
agentic_enable <- function(auto_process = TRUE) {
  cfg <- tryCatch(get_api_config(), error = function(e) NULL)
  if (is.null(cfg) && auto_process) {
    cli::cli_alert_warning(
      "No API key configured. Error interceptor enabled in suggestion mode.\n",
      "Run agentic_config(api_key = \"sk-...\", save = TRUE) to enable auto-processing."
    )
    auto_process <- FALSE
  }

  old_error <- getOption("error")
  options(agenticr.old_error_handler = old_error)

  agenticr_env$.error_handler_active <- FALSE

  options(
    agenticr.error_handler = function() {
      if (isTRUE(agenticr_env$.error_handler_active)) return()
      agenticr_env$.error_handler_active <- TRUE
      on.exit(agenticr_env$.error_handler_active <- FALSE)

      err_call <- sys.call(1)
      if (is.null(err_call)) return()

      call_text <- paste(deparse(err_call), collapse = "")
      if (!is_natural_language(call_text)) return()

      cli::cli_text("")
      if (auto_process && !is.null(cfg)) {
        cli::cli_alert_info("Detected natural language. Processing with AgenticR...")
        cat("\n")
        tryCatch(
          process_with_agent(call_text),
          error = function(e) {
            cli::cli_alert_danger("AgenticR processing failed: {conditionMessage(e)}")
          }
        )
      } else {
        cli::cli_alert_info(
          "This looks like natural language. Run {.code agentic()} to enable AI assistance."
        )
      }
    }
  )

  options(
    error = function() {
      if (exists("agenticr.error_handler", where = .Options)) {
        tryCatch(getOption("agenticr.error_handler")(), error = function(e) NULL)
      }
    }
  )

  cli::cli_alert_success(
    "AgenticR error interceptor enabled{cli::if(auto_process, ' (auto-process mode)')}."
  )
  invisible()
}

#' Disable error interceptor
#'
#' @export
agentic_disable <- function() {
  if (!is.null(getOption("agenticr.error_handler"))) {
    old_error <- getOption("agenticr.old_error_handler")
    if (!is.null(old_error)) {
      options(error = old_error)
    } else {
      options(error = NULL)
    }
    options(agenticr.error_handler = NULL, agenticr.old_error_handler = NULL)
    cli::cli_alert_success("AgenticR error interceptor disabled.")
  }
  invisible()
}
