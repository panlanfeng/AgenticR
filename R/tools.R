#' Tool definitions for the LLM agent
#'
#' Tools available to the LLM for interacting with the R session.
#'
#' @keywords internal

get_tool_definitions <- function() {
  list(
    list(
      type = "function",
      "function" = list(
        name = "execute_r_code",
        description = paste0(
          "Execute R code in the current session and return the output. ",
          "Use this to run any R code: load libraries, manipulate data, ",
          "create plots, run statistical tests, etc. ",
          "IMPORTANT: Execute exactly ONE logical step per call. ",
          "Do not chain multiple independent operations. ",
          "Always check results before proceeding to next step."
        ),
        parameters = list(
          type = "object",
          properties = list(
            code = list(
              type = "string",
              description = "R code to execute. One logical step only."
            )
          ),
            required = list("code")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "get_dataframe_info",
        description = paste0(
          "Get structure information about a data frame or tibble in the ",
          "current environment. Returns column names, types, dimensions, ",
          "and first few rows. Use this before manipulating any dataset."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the data frame variable to inspect"
            )
          ),
          required = list("name")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "search_variables",
        description = paste0(
          "Search for variables in the current R environment by name pattern. ",
          "Use this to find datasets, functions, or results that might exist."
        ),
        parameters = list(
          type = "object",
          properties = list(
            pattern = list(
              type = "string",
              description = "Case-insensitive pattern to search for in variable names"
            )
          )
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "read_file",
        description = paste0(
          "Read the contents of a file from the file system. ",
          "Use this to examine scripts, data files, or configuration. ",
          "For large files, use offset and limit to read specific sections."
        ),
        parameters = list(
          type = "object",
          properties = list(
            file_path = list(
              type = "string",
              description = "Path to the file to read"
            ),
            offset = list(
              type = "integer",
              description = "Line number to start reading from (1-indexed, default: 1)"
            ),
            limit = list(
              type = "integer",
              description = "Maximum lines to read (default: 2000, max: 2000)"
            ),
            pattern = list(
              type = "string",
              description = "Regex pattern to filter lines. When set, only matching lines (with context) are returned."
            ),
            context_around = list(
              type = "integer",
              description = "Lines of context to show before and after each match when using pattern (default: 2)"
            )
          ),
          required = list("file_path")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "get_function_source",
        description = paste0(
          "Get the source code of an R function. Returns the full function ",
          "definition including the body. Use this to understand how a ",
          "function is implemented. Specify package for functions from ",
          "specific packages."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the R function to look up"
            ),
            package = list(
              type = "string",
              description = "Package name where the function is defined (optional)"
            )
          ),
          required = list("name")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "get_function_help",
        description = paste0(
          "Get R documentation for a function. Returns the help page content ",
          "including description, usage, arguments, and examples. ",
          "Specify package when looking up a function from a specific package ",
          "(e.g. dplyr, ggplot2). Use this when unsure about a function's ",
          "syntax or parameters."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the R function to look up"
            ),
            package = list(
              type = "string",
              description = "Package name where the function is defined (optional)"
            )
          ),
          required = list("name")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "grep_search",
        description = paste0(
          "Search file contents for a regex pattern. Uses ripgrep (rg) if ",
          "available, grep as fallback. Returns matching lines with file ",
          "paths. Use to find code, function definitions, or any content ",
          "across files."
        ),
        parameters = list(
          type = "object",
          properties = list(
            pattern = list(
              type = "string",
              description = "Regex pattern to search for"
            ),
            path = list(
              type = "string",
              description = "Directory or file to search in (default: current directory)"
            ),
            context_lines = list(
              type = "integer",
              description = "Lines of context around each match (default: 2)"
            )
          ),
          required = list("pattern")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "list_files",
        description = paste0(
          "List files and directories in a path. Automatically skips .git, ",
          ".svn, and common build artifacts. If more than 100 files match, ",
          "suggests narrowing with the pattern parameter or using grep_search."
        ),
        parameters = list(
          type = "object",
          properties = list(
            path = list(
              type = "string",
              description = "Directory to list (default: current working directory)"
            ),
            pattern = list(
              type = "string",
              description = "Glob-style pattern to filter (e.g. '*.R', '**/*.py'). Default: all files."
            )
          )
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "file_edit",
        description = paste0(
          "Replace a string in a file. The old_string must be unique -- ",
          "provide enough surrounding text to identify the exact occurrence. ",
          "If multiple matches exist, add more context lines to make it unique, ",
          "or set replace_all to true to replace all occurrences. ",
          "You must read the file with read_file before editing it."
        ),
        parameters = list(
          type = "object",
          properties = list(
            file_path = list(
              type = "string",
              description = "Path to the file to edit"
            ),
            old_string = list(
              type = "string",
              description = "The exact text to replace. This is a literal string match, NOT a regex pattern. Must match exactly including whitespace and line breaks."
            ),
            new_string = list(
              type = "string",
              description = "The replacement text"
            ),
            replace_all = list(
              type = "boolean",
              description = "Set to true to replace all occurrences of old_string (default: false)"
            )
          ),
          required = list("file_path", "old_string", "new_string")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "file_write",
        description = paste0(
          "Create or overwrite a file with new content. Use to write new ",
          "files or completely replace existing ones."
        ),
        parameters = list(
          type = "object",
          properties = list(
            file_path = list(
              type = "string",
              description = "Path to the file to write"
            ),
            content = list(
              type = "string",
              description = "The full content to write to the file"
            )
          ),
          required = list("file_path", "content")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "install_package",
        description = paste0(
          "Request to install an R package. The user will be prompted for ",
          "confirmation before installation proceeds."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the CRAN package to install"
            )
          ),
          required = list("name")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "task_list",
        description = "List all current tasks with their IDs, statuses, and priorities. Use this to review progress before deciding what to do next.",
        parameters = list(type = "object")
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "task_write",
        description = "Create or replace the entire task list. Use for initial planning or restructuring. Each task needs content, status, and priority.",
        parameters = list(
          type = "object",
          properties = list(
            todos = list(
              type = "array", description = "The complete task list",
              items = list(
                type = "object",
                properties = list(
                  content = list(type = "string", description = "Brief description of the task"),
                  status = list(type = "string", description = "Status: pending, in_progress, completed, or cancelled"),
                  priority = list(type = "string", description = "Priority: high, medium, or low")
                ),
                required = list("content", "status", "priority")
              )
            )
          ),
          required = list("todos")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "task_update",
        description = "Update a single task by its ID. Call immediately after finishing each task -- do not batch updates.",
        parameters = list(
          type = "object",
          properties = list(
            id = list(type = "integer", description = "Task ID to update (1-indexed, from task_list)"),
            status = list(type = "string", description = "New status: pending, in_progress, completed, or cancelled"),
            content = list(type = "string", description = "Updated description (optional)")
          ),
          required = list("id", "status")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "load_skill_body",
        description = paste0(
          "Load the full instructions for an available skill. ",
          "Use this when you need to apply a skill's detailed rules ",
          "that are not summarized in the frontmatter."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the skill to load"
            )
          ),
          required = list("name")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "memory_write",
        description = paste0(
          "Write information to persistent memory. Use this when the user asks ",
          "you to remember something, or when you learn something important about ",
          "their preferences or environment."
        ),
        parameters = list(
          type = "object",
          properties = list(
            section = list(
              type = "string",
              description = "Memory section: preferences, environment, corrections, or learnings"
            ),
            content = list(
              type = "string",
              description = "Content to append to this memory section (Markdown format)"
            )
          ),
          required = list("section", "content")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "create_skill",
        description = paste0(
          "Create a new reusable skill. Use this when the user asks you to remember a pattern, ",
          "or when you notice a recurring workflow that should become a skill. ",
          "Creates SKILL.md with YAML frontmatter and instructions."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Skill name (lowercase, hyphens allowed, e.g. 'r-style')"
            ),
            description = list(
              type = "string",
              description = "One-line description of what this skill does"
            ),
            trigger = list(
              type = "string",
              description = "When to apply this skill (e.g. 'when generating R code' or 'when user asks for plots')"
            ),
            body = list(
              type = "string",
              description = "Full skill instructions in Markdown. Include examples, rules, and best practices."
            )
          ),
          required = list("name", "description", "body")
        )
      )
    ),
    list(
      type = "function",
      "function" = list(
        name = "append_skill_memory",
        description = paste0(
          "Append experience notes to a skill's memory. Use this when you learn something ",
          "new about how a skill works, what inputs it handles well, or known failure modes."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the skill to append memory to"
            ),
            content = list(
              type = "string",
              description = "Experience note to append (Markdown, include date and context)"
            )
          ),
          required = list("name", "content")
        )
      )
    )
  )
}

#' Truncate large tool results to avoid bloating LLM context
#'
#' Results > 20K tokens are written to a file in the session outputs dir.
#' The context receives the last 2K tokens + a [full output saved to ...] note.
#' read_file results are never truncated.
#'
#' @keywords internal
truncate_tool_result <- function(result, tool_name) {
  if (is.null(result) || nchar(result) == 0) return(result)

  # read_file never truncated -- LLM needs full file content
  if (identical(tool_name, "read_file")) return(result)

  MAX_TOKENS <- 20000
  PREVIEW_TOKENS <- 2000
  approx_tokens <- nchar(result) / 3.5

  if (approx_tokens <= MAX_TOKENS) return(result)

  output_file <- file.path(agenticr_env$outputs_dir,
    paste0("tool_", agenticr_env$turn_counter, "_",
           gsub("[^a-zA-Z0-9]", "_", tool_name), ".txt"))

  writeLines(result, output_file)

  # Show the LAST 2K tokens (most recent output is most relevant)
  preview_chars <- PREVIEW_TOKENS * 3.5
  preview <- if (nchar(result) > preview_chars) {
    substr(result, nchar(result) - preview_chars + 1, nchar(result))
  } else result

  paste0(
    "[Note: full output (", round(approx_tokens), " tokens) saved to ",
    output_file, ". Use read_file to access.]\n\n",
    "[Last ", PREVIEW_TOKENS, " tokens preview]\n",
    preview
  )
}
#'
#' @param tool_name Name of the tool to execute
#' @param arguments Named list of arguments
#' @return Character string with the result
#'
#' @keywords internal
execute_tool <- function(tool_name, arguments) {
  result <- switch(
    tool_name,
    execute_r_code = tool_execute_r_code(arguments$code),
    get_dataframe_info = tool_get_dataframe_info(arguments$name),
    search_variables = tool_search_variables(arguments$pattern),
    read_file = tool_read_file(arguments$file_path, arguments$offset, arguments$limit, arguments$pattern, arguments$context_around),
    get_function_help = tool_get_function_help(arguments$name, arguments$package),
    get_function_source = tool_get_function_source(arguments$name, arguments$package),
    grep_search = tool_grep_search(arguments$pattern, arguments$path %||% ".", arguments$context_lines %||% 2L),
    list_files = tool_list_files(arguments$path, arguments$pattern),
    file_edit = tool_file_edit(arguments$file_path, arguments$old_string, arguments$new_string, arguments$replace_all),
    file_write = tool_file_write(arguments$file_path, arguments$content),
    install_package = tool_install_package(arguments$name),
    task_list = tool_task_list(),
    task_write = tool_task_write(arguments$todos),
    task_update = tool_task_update(arguments$id, arguments$status, arguments$content),
    load_skill_body = tool_load_skill_body(arguments$name),
    memory_write = tool_memory_write(arguments$section, arguments$content),
    create_skill = tool_create_skill(arguments$name, arguments$description, arguments$trigger, arguments$body),
    append_skill_memory = tool_append_skill_memory(arguments$name, arguments$content),
    {
      if (startsWith(tool_name, "mcp_")) {
        mcp_execute_tool(tool_name, arguments)
      } else {
        paste0("Unknown tool: ", tool_name)
      }
    }
  )
  truncate_tool_result(result, tool_name)
}

#' Execute R code and capture output
#'
#' @keywords internal
tool_execute_r_code <- function(code) {
  if (is.null(code) || nchar(trimws(code)) == 0) {
    return("Error: No code provided")
  }

  cat(cli::col_green(paste0("\u2192 ", trimws(code), "\n")))
  utils::flush.console()

  warnings_list <- list()
  output_lines <- character(0)

  pager_file <- tempfile("agenticr_pager_")
  old_opts <- options(
    pager = function(files, header, title, delete.file) {
      if (!is.null(files) && file.exists(files)) {
        writeLines(readLines(files, warn = FALSE), pager_file)
      }
    },
    help_type = "text",
    browser = function(url) message("Browser suppressed: ", url)
  )

  on.exit({
    options(old_opts)
    if (file.exists(pager_file)) file.remove(pager_file)
  }, add = TRUE)

  output <- tryCatch({
    con <- textConnection("output_lines", open = "w", local = TRUE)
    sink(con, type = "output")
    sink(con, type = "message")

    withCallingHandlers({
      expr <- parse(text = code)
      result <- withVisible(eval(expr, envir = .GlobalEnv))
      result
    }, warning = function(w) {
      warnings_list <<- c(warnings_list, list(conditionMessage(w)))
      invokeRestart("muffleWarning")
    })

    sink(type = "message")
    sink(type = "output")
    close(con)

    lines <- output_lines
    if (result$visible) {
      result_str <- utils::capture.output(print(result$value))
      lines <- c(lines, result_str)
    }

    if (file.exists(pager_file) && file.info(pager_file)$size > 0) {
      pager_lines <- readLines(pager_file, warn = FALSE)
      lines <- c(lines, pager_lines)
    }

    paste(lines, collapse = "\n")
  }, error = function(e) {
    tryCatch({
      sink(type = "message")
      sink(type = "output")
      close(con)
    }, error = function(x) NULL)
    paste0("Error: ", conditionMessage(e))
  })

  if (length(warnings_list) > 0) {
    warn_text <- paste("Warning:", paste(warnings_list, collapse = "; "))
    output <- paste0(warn_text, "\n", output)
  }

  output <- trimws(output)
  output
}

#' Get dataframe information
#'
#' @keywords internal
tool_get_dataframe_info <- function(name) {
  if (is.null(name) || !exists(name, envir = .GlobalEnv)) {
    return(paste0("Error: Variable '", name, "' not found in the environment"))
  }

  obj <- get(name, envir = .GlobalEnv)

  if (!is.data.frame(obj)) {
    return(paste0(
      "Error: '", name, "' is not a data frame, it is a ",
      paste(class(obj), collapse = "/")
    ))
  }

  lines <- c()
  lines <- c(lines, paste0("Data frame: ", name))
  lines <- c(lines, paste0("Dimensions: ", nrow(obj), " rows x ", ncol(obj), " cols"))
  lines <- c(lines, "")
  lines <- c(lines, "Column names and types:")
  for (col in names(obj)) {
    col_class <- class(obj[[col]])
    lines <- c(lines, paste0("  $", col, " : ", paste(col_class, collapse = "/")))
  }

  lines <- c(lines, "")
  lines <- c(lines, "First 5 rows:")
  preview <- utils::capture.output(print(utils::head(obj, 5)))
  lines <- c(lines, preview)

  paste(lines, collapse = "\n")
}

#' Search for variables in the environment
#'
#' @keywords internal
tool_search_variables <- function(pattern) {
  if (is.null(pattern) || nchar(trimws(pattern)) == 0) {
    pattern <- ".*"
  }

  all_vars <- ls(envir = .GlobalEnv, all.names = TRUE)
  vars <- grep(pattern, all_vars, value = TRUE, ignore.case = TRUE)

  if (length(vars) == 0) {
    return(paste0("No variables matching pattern '", pattern, "' found."))
  }

  lines <- c(paste0("Variables matching '", pattern, "' (", length(vars), " found):"))
  for (v in vars) {
    obj <- get(v, envir = .GlobalEnv)
    obj_class <- paste(class(obj), collapse = "/")
    obj_info <- if (is.data.frame(obj)) {
      paste0(nrow(obj), "x", ncol(obj))
    } else if (is.vector(obj) && !is.list(obj)) {
      paste0("length ", length(obj))
    } else {
      typeof(obj)
    }
    lines <- c(lines, paste0("  ", v, " (", obj_class, ", ", obj_info, ")"))
  }

  paste(lines, collapse = "\n")
}

#' Read a file
#'
#' @keywords internal
tool_read_file <- function(file_path, offset = NULL, limit = NULL, pattern = NULL, context_around = NULL) {
  if (is.null(file_path) || nchar(trimws(file_path)) == 0) {
    return("Error: No file path provided")
  }

  if (!file.exists(file_path)) {
    return(paste0("Error: File '", file_path, "' not found"))
  }

  fsize <- file.info(file_path)$size
  if (!is.na(fsize) && fsize > 262144) {
    return(paste0(
      "The file is too large (", format(fsize, big.mark = ","), " bytes). ",
      "Use offset and limit parameters to read selected lines of the file, ",
      "or search for specific content instead of reading the whole file."
    ))
  }

  content <- tryCatch(
    readLines(file_path, warn = FALSE),
    error = function(e) return(paste0("Error reading file: ", conditionMessage(e)))
  )
  if (!is.character(content)) return(content)

  total_lines <- length(content)
  start_line <- if (is.null(offset) || is.na(offset)) 1L else max(1L, as.integer(offset))
  MAX_LINES <- 2000L
  limit_val <- if (!is.null(limit) && !is.na(limit)) min(as.integer(limit), MAX_LINES) else MAX_LINES
  end_line <- min(start_line + limit_val - 1L, total_lines)

  resolved <- normalizePath(file_path, mustWork = FALSE)
  agenticr_env$files_read[[resolved]] <- TRUE
  MAX_CHARS <- 25000L

  # Pattern-based search within the file
  if (!is.null(pattern) && nchar(trimws(pattern)) > 0) {
    ctx <- if (is.null(context_around) || is.na(context_around)) 2L else max(0L, as.integer(context_around))
    matches <- grep(pattern, content, ignore.case = FALSE, perl = TRUE)
    if (length(matches) == 0) {
      return(paste0("No matches for '", pattern, "' in ", resolved))
    }
    # Build match blocks with context
    shown <- integer(0)
    for (m in matches) {
      start <- max(1L, m - ctx)
      end <- min(total_lines, m + ctx)
      shown <- unique(c(shown, start:end))
    }
    shown <- sort(shown)
    match_lines <- content[shown]
    match_nums <- which(seq_along(content) %in% shown)
    body <- c(
      paste0("[File: ", resolved, "]"),
      paste0("[Lines: ", total_lines, " total]"),
      paste0("[Pattern: '", pattern, "' -- ", length(matches), " matches showing ", length(shown), " lines with +/-", ctx, " context]"),
      "",
      format_lines(match_lines, shown[1])
    )
    result <- paste(body, collapse = "\n")
    if (nchar(result) > MAX_CHARS) {
      return(trim_to_limit(result, MAX_CHARS))
    }
    return(result)
  }

  # For large files read without explicit offset, show head + tail
  if (is.null(offset) && total_lines > limit_val + 200) {
    HEAD_LINES <- 80L
    TAIL_LINES <- 40L
    head_content <- content[1:min(HEAD_LINES, total_lines)]
    tail_start <- max(HEAD_LINES + 1, total_lines - TAIL_LINES + 1)
    tail_content <- content[tail_start:total_lines]
    shown_lines <- HEAD_LINES + TAIL_LINES

    head_block <- format_lines(head_content, 1)
    tail_block <- format_lines(tail_content, tail_start)
    body <- c(
      paste0("[File: ", resolved, "]"),
      paste0("[Size: ", format(fsize, big.mark = ","), " bytes]"),
      paste0("[Lines: ", total_lines, " total]"),
      paste0("[Range: 1-", HEAD_LINES, " and ", tail_start, "-", total_lines,
             " (", shown_lines, " of ", total_lines, " lines shown)]"),
      paste0("[Next: use offset=", HEAD_LINES + 1, " to continue reading]"),
      "",
      head_block,
      paste0("  --- ", total_lines - HEAD_LINES - TAIL_LINES, " lines not shown ---"),
      tail_block
    )
    return(paste(body, collapse = "\n"))
  }

  shown_content <- content[start_line:end_line]
  shown_lines <- length(shown_content)
  truncated <- end_line < total_lines

  body <- c(
    paste0("[File: ", resolved, "]"),
    paste0("[Size: ", format(fsize, big.mark = ","), " bytes]"),
    paste0("[Lines: ", total_lines, " total]"),
    paste0("[Range: ", start_line, "-", end_line,
           " (", shown_lines, if (truncated) paste0(" of ", total_lines) else "", " lines)]"),
    if (truncated) paste0("[Next: use offset=", end_line + 1, " to read more]") else NULL,
    if (start_line > 1) paste0("[Note: reading from offset ", start_line, "]") else NULL,
    "",
    format_lines(shown_content, start_line)
  )

  result <- paste(body, collapse = "\n")
  if (nchar(result) > MAX_CHARS) {
    return(paste0(
      "File content exceeds ", MAX_CHARS, " characters. ",
      "Use offset and limit parameters to read selected lines of the file, ",
      "or search for specific content instead of reading the whole file."
    ))
  }
  result
}

#' Truncate output at char limit with guidance
#'
#' @keywords internal
trim_to_limit <- function(result, max_chars) {
  truncated <- substr(result, 1, max_chars - 100)
  paste0(truncated, "\n\n[Output truncated at ", max_chars, " characters. ",
         "Use offset, limit, or pattern to narrow results.]")
}

#' Format lines with zero-padded line numbers
#'
#' @keywords internal
format_lines <- function(lines, start_line) {
  end <- start_line + length(lines) - 1
  width <- nchar(as.character(end))
  fmt <- paste0("%", width, "d | %s")
  sapply(seq_along(lines), function(i) sprintf(fmt, start_line + i - 1, lines[i]))
}

#' Get R function source code
#'
#' @keywords internal
tool_get_function_source <- function(name, package = NULL) {
  if (is.null(name) || nchar(trimws(name)) == 0) {
    return("Error: No function name provided")
  }

  src <- tryCatch({
    if (!is.null(package) && nchar(trimws(package)) > 0) {
      fn <- getFromNamespace(name, package)
    } else {
      fn <- get(name, envir = .GlobalEnv, inherits = TRUE)
    }
    paste(deparse(fn), collapse = "\n")
  }, error = function(e) {
    tryCatch({
      if (!is.null(package) && nchar(trimws(package)) > 0) {
        fn <- getFromNamespace(name, package)
      } else {
        fn <- getAnywhere(name)$objs[[1]]
      }
      paste(deparse(fn), collapse = "\n")
    }, error = function(e2) paste0("Error: ", conditionMessage(e)))
  })

  if (grepl("^Error:", src)) return(src)

  if (nchar(src) > 4000) {
    src <- paste0(substr(src, 1, 4000), "\n... [truncated]")
  }

  src
}

#' Get R function documentation
#'
#' @keywords internal
tool_get_function_help <- function(name, package = NULL) {
  if (is.null(name) || nchar(trimws(name)) == 0) {
    return("Error: No function name provided")
  }

  pager_file <- tempfile("agenticr_help_")
  old_opts <- options(
    pager = function(files, header, title, delete.file) {
      if (!is.null(files) && file.exists(files)) {
        writeLines(readLines(files, warn = FALSE), pager_file)
      }
    },
    help_type = "text",
    browser = function(url) message("Browser suppressed: ", url)
  )
  on.exit({
    options(old_opts)
    if (file.exists(pager_file)) file.remove(pager_file)
  })

  help_lines <- tryCatch(
    utils::capture.output(suppressWarnings(do.call(help,
      list(topic = name %||% "", package = package, help_type = "text")))),
    error = function(e) character(0)
  )

  if (file.exists(pager_file) && file.info(pager_file)$size > 0) {
    pager_lines <- readLines(pager_file, warn = FALSE)
    help_lines <- c(pager_lines, help_lines)
  }

  help_lines <- help_lines[nchar(trimws(help_lines)) > 0]

  if (length(help_lines) == 0) {
    return(paste0("No documentation found for '", name, "'"))
  }

  if (length(help_lines) > 80) {
    help_lines <- c(
      help_lines[1:80],
      paste0("... [", length(help_lines) - 80, " more lines]")
  )
}

  paste(help_lines, collapse = "\n")
}

#' List files in a directory, ignoring VCS and build artifacts
#'
#' @keywords internal
tool_list_files <- function(path = NULL, pattern = NULL) {
  resolved <- path.expand(path %||% ".")
  parts <- strsplit(resolved, "[/\\\\]")[[1]]
  if (length(parts) > 0 && grepl("^~", parts[1])) {
    resolved <- normalizePath(resolved, mustWork = FALSE)
  }

  SKIP_DIRS <- c(".git", ".svn", ".hg", "__pycache__", ".Rproj.user",
                 "node_modules", "renv", "packrat", ".venv", "venv")

  recursive <- !is.null(pattern) && grepl("\\*\\*", pattern)
  files <- tryCatch(
    list.files(resolved, pattern = pattern,
               recursive = recursive, all.files = TRUE,
               full.names = FALSE, include.dirs = TRUE),
    error = function(e) list.files(resolved, recursive = recursive,
                                   all.files = TRUE, full.names = FALSE,
                                   include.dirs = TRUE)
  )

  for (d in SKIP_DIRS) {
    files <- files[!grepl(paste0("(^|/)", gsub("\\.", "\\\\.", d), "($|/)"), files)]
  }
  files <- files[!files %in% c(".", "..")]

  if (!is.null(pattern) && !recursive) {
    files <- files[!grepl("/", files)]
  }

  if (length(files) > 100) {
    return(paste0(
      length(files), " files found. Too many to list.\n",
      "Use the 'pattern' parameter to narrow results (e.g. pattern='*.R' or pattern='test*'), ",
      "or use grep_search to search by content instead."
    ))
  }

  if (length(files) == 0) {
    return(paste0("No files found in ", resolved,
                  if (!is.null(pattern)) paste0(" matching '", pattern, "'") else ""))
  }

  lines <- character(0)
  for (f in files) {
    full <- file.path(resolved, f)
    is_dir <- dir.exists(full)
    prefix <- if (is_dir) "/" else ""
    suffix <- if (!is_dir) {
      tryCatch({
        sz <- file.info(full)$size
        if (!is.na(sz)) paste0(" (", format(sz, big.mark = ","), " bytes)") else ""
      }, error = function(e) "")
    } else ""
    lines <- c(lines, paste0(prefix, f, suffix))
  }

  paste(c(paste0(length(lines), " entries in ", resolved), lines),
        collapse = "\n")
}

#' Search file contents for a regex pattern using rg or grep
#'
#' @keywords internal
tool_grep_search <- function(pattern, path = ".", context_lines = 2) {
  if (is.null(pattern) || nchar(trimws(pattern)) == 0) {
    return("Error: No search pattern provided")
  }

  resolved <- path.expand(
    if (is.null(path) || nchar(trimws(path)) == 0) "." else path
  )
  if (!grepl("^[/~]|[A-Za-z]:", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  rg <- Sys.which("rg")
  if (nzchar(rg)) {
    cmd <- sprintf("rg --color=never -C %d %s %s 2>&1",
                   as.integer(context_lines), shQuote(pattern), shQuote(resolved))
  } else if (nzchar(Sys.which("grep"))) {
    cmd <- sprintf("grep -rnH --color=never %s %s 2>&1",
                   shQuote(pattern), shQuote(resolved))
  } else {
    cmd <- NULL
  }

  out <- if (is.null(cmd)) {
    tryCatch({
      files <- list.files(resolved, recursive = TRUE, full.names = TRUE)
      grep_result <- c()
      for (f in files) {
        if (file.info(f)$isdir) next
        if (file.info(f)$size > 1e6) next
        lines <- readLines(f, warn = FALSE)
        hits <- grep(pattern, lines, perl = TRUE)
        if (length(hits) > 0) {
          for (h in hits) {
            grep_result <- c(grep_result,
              paste0(f, ":", h, ":", lines[h]))
          }
        }
      }
      if (context_lines > 0 && length(grep_result) > 0) {
        grep_result <- c(grep_result,
          "[Note: context lines not available in pure-R fallback]")
      }
      grep_result
    }, error = function(e) character(0))
  } else {
    tryCatch(
      suppressWarnings(system(cmd, intern = TRUE, ignore.stderr = TRUE)),
      error = function(e) character(0)
    )
  }

  if (length(out) == 0 || all(nchar(trimws(out)) == 0)) {
    return(paste0("No matches for '", pattern, "' in ", resolved))
  }

  if (length(out) > 40) {
    out <- c(out[1:40], paste0("... (", length(out) - 40, " more matches)"))
  }

  result <- paste(out, collapse = "\n")
  if (nchar(result) > 4000) {
    result <- paste0(substr(result, 1, 4000), "\n... [output truncated]")
  }
  result
}

#' Compute a compact diff between old and new file content
#'
#' @keywords internal
compute_edit_diff <- function(old_content, new_content, file_path, context = 3) {
  old_lines <- strsplit(old_content, "\n")[[1]]
  new_lines <- strsplit(new_content, "\n")[[1]]
  n_old <- length(old_lines)
  n_new <- length(new_lines)

  # Find the first and last differing lines
  first_diff <- 1
  while (first_diff <= min(n_old, n_new) &&
         old_lines[first_diff] == new_lines[first_diff]) {
    first_diff <- first_diff + 1
  }

  last_old <- n_old
  last_new <- n_new
  while (last_old >= first_diff && last_new >= first_diff &&
         old_lines[last_old] == new_lines[last_new]) {
    last_old <- last_old - 1
    last_new <- last_new - 1
  }

  if (first_diff > last_old && first_diff > last_new) {
    return(paste0("Edited ", file_path, " (no visible change)"))
  }

  ctx_start <- max(1, first_diff - context)
  ctx_end_old <- min(n_old, last_old + context)
  ctx_end_new <- min(n_new, last_new + context)

  lines <- c(paste0("--- ", file_path), paste0("+++ ", file_path, " (edited)"))
  lines <- c(lines, paste0("@@ -", ctx_start, ",", ctx_end_old - ctx_start + 1,
         " +", ctx_start, ",", ctx_end_new - ctx_start + 1, " @@"))

  for (i in ctx_start:max(ctx_end_old, ctx_end_new)) {
    has_old <- i <= n_old
    has_new <- i <= n_new
    if (has_old && has_new) {
      if (old_lines[i] == new_lines[i]) {
        lines <- c(lines, paste0(" ", old_lines[i]))
      } else {
        if (i <= last_old) lines <- c(lines, paste0("-", old_lines[i]))
        if (i <= last_new) lines <- c(lines, paste0("+", new_lines[i]))
      }
    } else if (has_old && i <= last_old) {
      lines <- c(lines, paste0("-", old_lines[i]))
    } else if (has_new && i <= last_new) {
      lines <- c(lines, paste0("+", new_lines[i]))
    }
  }

  if (length(lines) > 40) {
    lines <- c(lines[1:40], paste0("... (", length(lines) - 40, " more diff lines)"))
  }

  paste(lines, collapse = "\n")
}

#' Replace a unique string in a file
#'
#' @keywords internal
tool_file_edit <- function(file_path, old_string, new_string, replace_all = FALSE) {
  if (is.null(file_path) || nchar(trimws(file_path)) == 0) {
    return("Error: No file path provided")
  }
  if (is.null(old_string) || nchar(old_string) == 0) {
    return("Error: No old_string provided")
  }
  if (is.null(replace_all)) replace_all <- FALSE

  resolved <- path.expand(file_path)
  if (!grepl("^[/~]|[A-Za-z]:", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  if (!file.exists(resolved)) {
    return(paste0("File not found: ", resolved))
  }

  resolved <- normalizePath(resolved, mustWork = TRUE)
  if (is.null(agenticr_env$files_read[[resolved]])) {
    return(paste0("File has not been read yet. Read it first with read_file: ", resolved))
  }

  content <- tryCatch(
    readLines(resolved, warn = FALSE),
    error = function(e) return(paste0("Error reading file: ", conditionMessage(e)))
  )
  if (is.character(content)) {
    content <- paste(content, collapse = "\n")
  }

  count <- 0
  pos <- 1
  while (TRUE) {
    found <- regexpr(old_string, substr(content, pos, nchar(content)), fixed = TRUE)[1]
    if (found == -1) break
    count <- count + 1
    pos <- pos + found + nchar(old_string) - 1
  }

  if (count == 0) {
    return(paste0("No match found for the given old_string in ", resolved))
  }
  if (!replace_all && count > 1) {
    return(paste0("Found ", count, " matches -- old_string must be unique. Provide more context to make it unique, or set replace_all = true."))
  }

  if (replace_all) {
    new_content <- gsub(old_string, new_string, content, fixed = TRUE)
  } else {
    new_content <- sub(old_string, new_string, content, fixed = TRUE)
  }

  tryCatch(
    writeLines(new_content, resolved),
    error = function(e) return(paste0("Error writing file: ", conditionMessage(e)))
  )

  compute_edit_diff(content, new_content, resolved)
}

#' Create or overwrite a file
#'
#' @keywords internal
tool_file_write <- function(file_path, content) {
  if (is.null(file_path) || nchar(trimws(file_path)) == 0) {
    return("Error: No file path provided")
  }
  if (is.null(content)) {
    content <- ""
  }

  resolved <- path.expand(file_path)
  if (!grepl("^[/~]|[A-Za-z]:", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  dir_path <- dirname(resolved)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  }

  old_content <- if (file.exists(resolved)) {
    tryCatch(paste(readLines(resolved, warn = FALSE), collapse = "\n"),
             error = function(e) "")
  } else ""

  tryCatch(
    writeLines(content, resolved),
    error = function(e) return(paste0("Error writing file: ", conditionMessage(e)))
  )

  if (nchar(old_content) > 0) {
    compute_edit_diff(old_content, content, resolved)
  } else {
    paste0("Created ", resolved, " (", file.info(resolved)$size, " bytes)")
  }
}

#' Request to install a package
#'
#' @keywords internal
tool_install_package <- function(name) {
  if (is.null(name)) {
    return("Error: No package name provided")
  }

  if (requireNamespace(name, quietly = TRUE)) {
    return(paste0("Package '", name, "' is already installed."))
  }

  should_install <- agenticr_env$ask_permission(
    paste0("Install package '", name, "' from CRAN?")
  )

  if (should_install) {
    utils::install.packages(name, repos = "https://cloud.r-project.org")
    return(paste0("Package '", name, "' installed successfully."))
  }

  paste0("Installation of '", name, "' was declined by user.")
}

#' List all current tasks
#'
#' @keywords internal
tool_task_list <- function() {
  if (length(agenticr_env$tasks) == 0 || nrow(agenticr_env$tasks) == 0) {
    return("No tasks yet. Use task_write to create the first task list.")
  }
  t <- agenticr_env$tasks; n <- nrow(t)
  done <- sum(t$status == "completed"); cancelled <- sum(t$status == "cancelled")
  active <- sum(t$status == "in_progress"); pending <- sum(t$status == "pending")

  lines <- c(sprintf("Tasks: %d/%d (%d pending, %d in_progress)", done, n - cancelled, pending, active), "")
  for (i in seq_len(n)) {
    item <- t[i, ]
    mark <- switch(item$status, completed = "[x]", in_progress = "[>]", cancelled = "[-]", "[ ]")
    lines <- c(lines, sprintf("#%d %s %s (%s)", i, mark, item$content, item$priority))
  }
  if (pending > 0) {
    lines <- c(lines, "", sprintf("Next: start task #%d", which(t$status == "pending")[1]))
  } else if (done == n - cancelled) {
    lines <- c(lines, "", "All active tasks completed.")
  }
  paste(lines, collapse = "\n")
}

#' Create or replace the entire task list
#'
#' @keywords internal
tool_task_write <- function(todos) {
  if (is.null(todos) || length(todos) == 0) {
    return("Error: todos must be a non-empty array of tasks")
  }
  df <- data.frame(id = integer(), content = character(), status = character(),
                   priority = character(), stringsAsFactors = FALSE)
  for (i in seq_along(todos)) {
    t <- todos[[i]]
    df <- rbind(df, data.frame(id = i, content = t$content %||% "",
      status = t$status %||% "pending", priority = t$priority %||% "medium",
      stringsAsFactors = FALSE))
  }
  agenticr_env$tasks <- df
  n <- nrow(df); done <- sum(df$status == "completed")
  pending <- sum(df$status == "pending"); in_prog <- sum(df$status == "in_progress")
  paste0(
    "Tasks: ", n, " total, ", done, " completed, ", in_prog, " in_progress, ", pending, " pending.\n",
    if (pending > 0) paste0("Start with task #", which(df$status == "pending")[1], ".")
    else if (in_prog > 0) "Continue the task in progress."
    else "All tasks resolved."
  )
}

#' Update a single task by its ID
#'
#' @keywords internal
tool_task_update <- function(id, status, content = NULL) {
  if (is.null(id) || is.null(status)) return("Error: id and status are required")
  if (length(agenticr_env$tasks) == 0 || nrow(agenticr_env$tasks) == 0) {
    return("No tasks exist. Use task_write to create the first task list.")
  }
  id <- as.integer(id)
  if (id < 1 || id > nrow(agenticr_env$tasks)) {
    return(paste0("Error: task #", id, " does not exist. Valid: 1-", nrow(agenticr_env$tasks)))
  }
  old_status <- agenticr_env$tasks$status[id]
  agenticr_env$tasks$status[id] <- status
  if (!is.null(content) && nchar(trimws(content)) > 0) {
    agenticr_env$tasks$content[id] <- trimws(content)
  }
  t <- agenticr_env$tasks; n <- nrow(t)
  done <- sum(t$status == "completed"); cancelled <- sum(t$status == "cancelled")
  mark <- switch(status, completed = "[x]", in_progress = "[>]", cancelled = "[-]", "[ ]")
  lines <- sprintf("Task #%d: %s -> %s %s", id, old_status, mark, t$content[id])
  if (done == n - cancelled) {
    lines <- c(lines, "All tasks complete.")
  } else {
    pending_idx <- which(t$status == "pending")
    if (length(pending_idx) > 0) {
      lines <- c(lines, sprintf("Progress: %d/%d. Next: #%d.", done, n - cancelled, pending_idx[1]))
    }
  }
  paste(lines, collapse = "\n")
}

#' Write to persistent memory, updating the index
#'
#' @keywords internal
tool_memory_write <- function(section, content) {
  if (is.null(section) || is.null(content) || nchar(trimws(content)) == 0) {
    return("Error: section and non-empty content are required")
  }
  valid_sections <- c("preferences", "environment", "corrections", "learnings")
  if (!section %in% valid_sections) {
    return(paste0("Error: section must be one of: ", paste(valid_sections, collapse = ", ")))
  }

  dir.create(agenticr_env$memory_dir, showWarnings = FALSE, recursive = TRUE)
  section_file <- file.path(agenticr_env$memory_dir, paste0(section, ".md"))
  cat("\n", content, "\n", file = section_file, append = TRUE)

  index_file <- agenticr_env$memory_file
  existing_index <- if (file.exists(index_file)) {
    tryCatch(readLines(index_file, warn = FALSE), error = function(e) character(0))
  } else character(0)

  section_header <- paste0("## ", section, ".md")
  if (!any(grepl(section_header, existing_index, fixed = TRUE))) {
    summary <- if (nchar(content) > 120) paste0(substr(content, 1, 120), "...") else content
    summary <- gsub("\n", " ", summary)
    cat(paste(section_header, paste0("- ", summary), "", sep = "\n"), "\n",
        file = index_file, append = TRUE)
  }

  paste0("Memory written to ", section, ".md.")
}

#' Create a new skill with YAML frontmatter
#'
#' @keywords internal
tool_create_skill <- function(name, description, trigger = NULL, body) {
  if (is.null(name) || is.null(description) || is.null(body)) {
    return("Error: name, description, and body are required")
  }
  name <- tolower(gsub("[^a-z0-9-]", "-", name))
  skill_dir <- file.path(agenticr_dir(), "skills", name)
  if (dir.exists(skill_dir)) {
    return(paste0("Skill '", name, "' already exists. Use update_skill_body to modify it."))
  }
  dir.create(skill_dir, showWarnings = FALSE, recursive = TRUE)

  trigger_line <- if (!is.null(trigger) && nchar(trimws(trigger)) > 0) {
    paste0("trigger: ", trigger, "\n")
  } else ""

  frontmatter <- paste0(
    "---\n",
    "description: ", description, "\n",
    trigger_line,
    "---\n\n",
    body
  )
  writeLines(frontmatter, file.path(skill_dir, "SKILL.md"))
  writeLines("# Skill Memory\n", file.path(skill_dir, "MEMORY.md"))

  paste0("Skill '", name, "' created. It will be available on the next turn as [Available skill: ", name, "].")
}

#' Append experience notes to a skill's MEMORY.md
#'
#' @keywords internal
tool_append_skill_memory <- function(name, content) {
  if (is.null(name) || is.null(content) || nchar(trimws(content)) == 0) {
    return("Error: name and non-empty content are required")
  }
  skill_dir <- file.path(agenticr_dir(), "skills", name)
  if (!dir.exists(skill_dir)) {
    return(paste0("Skill '", name, "' not found. Create it first with create_skill."))
  }
  memory_file <- file.path(skill_dir, "MEMORY.md")
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("\n## %s\n%s\n", timestamp, content), file = memory_file, append = TRUE)
  paste0("Memory appended to skill '", name, "'.")
}
