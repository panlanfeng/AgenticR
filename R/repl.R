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
    cli::cli_alert_warning("AgenticR session is already active.")
    return(invisible())
  }

  agenticr_env$is_active <- TRUE
  agenticr_env$conversation <- list()
  agenticr_env$context_injected <- FALSE
  agenticr_env$stable_summary <- NULL
  agenticr_env$last_known_cwd <- getwd()
  agenticr_env$ask_permission <- function(prompt) {
    cli::cli_alert_warning(paste0("Permission required: ", prompt))
    ans <- readline("Proceed? [y/N] ")
    tolower(trimws(ans)) %in% c("y", "yes")
  }

  on.exit({
    agenticr_env$is_active <- FALSE
    agenticr_env$conversation <- list()
  })

  cli::cli_h1("AgenticR - AI-Powered R Console")
  cli::cli_text("Type natural language or R code.")
  cli::cli_text("Type {.code exit()} or press {.kbd Ctrl+C} to quit.")
  cli::cli_text("Type {.code /help} for assistance.")
  cat("\n")

  cfg <- tryCatch(get_api_config(), error = function(e) {
    cli::cli_alert_danger("{e$message}")
    cli::cli_text("")
    cli::cli_text("Set up your API key now:")
    cli::cli_text("  {.code agentic_config(api_key = \"sk-...\", save = TRUE)}")
    cat("\nEnter your API key (or press Enter to exit): ")
    key <- readline()
    if (key == "") return(invisible())
    agentic_config(api_key = key, save = TRUE)
    cli::cli_text("")
    tryCatch(get_api_config(), error = function(e2) {
      cli::cli_alert_danger("Still no valid key. Exiting.")
      return(NULL)
    })
    return(get_api_config())
  })
  if (is.null(cfg)) return(invisible())

  cli::cli_alert_info("Using model: {cfg$api_model} at {cfg$api_base}")

  while (TRUE) {
    input <- tryCatch(
      readline(prompt = "> "),
      interrupt = function(e) {
        cat("\n")
        return(NULL)
      }
    )

    if (is.null(input)) break

    input <- trimws(input)
    if (input == "" || input == "exit()" || input == "quit()") break

    if (grepl("^/", input)) {
      handle_slash_command(input)
      cat("\n")
      utils::flush.console()
      next
    }

    input <- read_complete_input(input)

    tryCatch(
      process_input(input),
      interrupt = function(e) {
        cli::cli_alert_warning("Interrupted.")
      },
      error = function(e) {
        cli::cli_alert_danger("Error: {conditionMessage(e)}")
        utils::flush.console()
      }
    )

    utils::flush.console()
  }

  cli::cli_text("")
  cli::cli_alert_info("Exiting AgenticR session.")
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
  is_incomplete <- grepl("unexpected end of input|INCOMPLETE_STRING|unexpected end of line",
                         err_msg, ignore.case = TRUE)

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
    if (next_line == "") break

    lines <- paste(lines, next_line, sep = "\n")

    parsed <- tryCatch(parse(text = lines), error = function(e) e)
    if (!inherits(parsed, "error")) break

    err_msg <- conditionMessage(parsed)
    is_incomplete <- grepl("unexpected end of input|INCOMPLETE_STRING|unexpected end of line",
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
    output <- tryCatch({
      con <- textConnection("output_lines", open = "w", local = TRUE)
      sink(con, type = "output")
      sink(con, type = "message")

      expr <- parse(text = input)
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
      TRUE
    }, error = function(e) {
      tryCatch({
        sink(type = "message")
        sink(type = "output")
        close(con)
      }, error = function(x) NULL)
      error_msg <- conditionMessage(e)
      if (grepl("could not find function", error_msg) ||
          grepl("unexpected", error_msg) ||
          grepl("object .* not found", error_msg)) {
        return(FALSE)
      }
      cli::cli_alert_danger("{error_msg}")
      return(NA)
    })

    if (identical(output, TRUE)) return(invisible())
    if (identical(output, NA)) return(invisible())
  }

  process_with_agent(input)
}

#' Process natural language input through the LLM agent
#'
#' @keywords internal
process_with_agent <- function(user_input) {
  cfg <- get_api_config()
  tools <- get_tool_definitions()

  messages <- list(list(role = "system", content = SYSTEM_PROMPT))

  if (!agenticr_env$context_injected) {
    agenticr_env$context_injected <- TRUE
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
    token_count <- estimate_tokens(messages)
    if (token_count > agenticr_env$max_context_tokens * 0.8) {
      messages <- run_compaction(messages)
    }

    response <- tryCatch(
      chat_completion(messages, tools),
      error = function(e) {
        stop("LLM API call failed: ", conditionMessage(e))
      }
    )

    if (length(response$choices) == 0) {
      cli::cli_alert_danger("LLM returned no choices.")
      break
    }

    choice <- response$choices[[1]]
    msg <- choice$message

    if (is.null(msg)) {
      break
    }

    if (!is.null(msg$tool_calls) && length(msg$tool_calls) > 0) {
      assistant_msg <- list(
        role = "assistant",
        tool_calls = msg$tool_calls,
        content = if (is.null(msg$content)) NULL else msg$content
      )
      messages <- c(messages, list(assistant_msg))

      for (tc in msg$tool_calls) {
        tool_name <- tc$`function`$name
        tool_args <- tryCatch(
          jsonlite::fromJSON(tc$`function`$arguments, simplifyVector = FALSE),
          error = function(e) list()
        )

        tool_result <- execute_tool(tool_name, tool_args)

        if (!is.null(tool_result) && nchar(trimws(tool_result)) > 0) {
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

    if (!is.null(msg$content) && nchar(msg$content) > 0) {
      content <- msg$content

      code_blocks <- extract_r_code_blocks(content)

      if (length(code_blocks) > 0) {
        text_only <- remove_r_code_blocks(content)
        if (nchar(trimws(text_only)) > 0) {
          cli::cli_text(cli::col_cyan(cli::style_italic("Agent response:")))
          cat(text_only, "\n")
          utils::flush.console()
        }
      } else {
        if (nchar(trimws(content)) > 0) {
          cli::cli_text(cli::col_cyan(cli::style_italic("Agent response:")))
          cat(content, "\n")
          utils::flush.console()
        }
      }

      messages <- c(messages, list(list(
        role = "assistant",
        content = content
      )))

      if (length(code_blocks) > 0) {
        for (code in code_blocks) {
          tool_result <- tool_execute_r_code(code)
          if (nchar(trimws(tool_result)) > 0) {
            cat(tool_result, "\n")
            utils::flush.console()
          }

          messages <- c(messages, list(list(
            role = "user",
            content = paste0(
              "The R code I just executed produced this output:\n",
              tool_result,
              "\n\nContinue with the analysis or explain the results if done."
            )
          )))
        }
        next
      }

      cat("\n")
      break
    }

    if (!is.null(choice$finish_reason) && choice$finish_reason == "stop") {
      break
    }
  }

  conv <- messages[sapply(messages, function(m) m$role != "system")]
  conv <- tail(conv, 20)

  while (length(conv) > 0 && conv[[1]]$role == "tool") {
    conv <- conv[-1]
  }

  agenticr_env$conversation <- conv
  utils::flush.console()
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
  "- Do not add comments in the R code.\n",
  "- Only do End-of-turn summary if the user explicitly requests it.\n",
  "- Do not repeat the user request.\n\n",


  "Ask for user permission before:\n",
  "- installing packages\n",
  "- deleting files or data\n\n",

  "When code fails with \"could not find function\", \"there is no package\", ",
  "\"object not found\", or similar:\n",
  "- First check if it is a typo or genuine missing dependency by reviewing ",
  "conversation history and the environment.\n",
  "- If a package is needed, request installation via tool.\n",
  "- If user declines, propose a built-in alternative."
)

#' Build the stable context block (injected once, never changes)
#'
#' @keywords internal
build_stable_context <- function() {
  paste0(
    "[Stable context]\n",
    "R version: ", R.version.string, "\n",
    "Platform: ", R.version$platform, "\n",
    "Start time: ", Sys.time(), "\n",
    "Working directory at start: ", getwd()
  )
}

#' Extract R code blocks from markdown text
#'
#' Supports \verb{```{r}...```} and \verb{```...```} blocks
#'
#' @keywords internal
extract_r_code_blocks <- function(text) {
  pattern <- "(?s)```\\s*(?:r|\\{r\\}|\\{R\\})?\\s*\\n?(.*?)```"
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
      cli::cli_li("{.code exit()} or {.kbd Ctrl+C} - Exit agentic session")
    },
    "/config" = {
      cfg <- get_api_config()
      print.agenticr_config(cfg)
    },
    "/clear" = {
      agenticr_env$conversation <- list()
      cli::cli_alert_success("Conversation history cleared.")
    },
    "/vars" = {
      cat(tool_search_variables(".*"), "\n")
    },
    {
      if (grepl("^/info\\s", input)) {
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

  options(
    agenticr.error_handler = function() {
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
    options(agenticr.error_handler = NULL)
    options(error = NULL)
    cli::cli_alert_success("AgenticR error interceptor disabled.")
  }
  invisible()
}
