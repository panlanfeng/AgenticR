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
          "Use this to examine scripts, data files, or configuration."
        ),
        parameters = list(
          type = "object",
          properties = list(
            file_path = list(
              type = "string",
              description = "Path to the file to read"
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
              description = "The exact text to replace (must match exactly, including whitespace)"
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

  # read_file never truncated — LLM needs full file content
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
    read_file = tool_read_file(arguments$file_path),
    get_function_help = tool_get_function_help(arguments$name, arguments$package),
    get_function_source = tool_get_function_source(arguments$name, arguments$package),
    grep_search = tool_grep_search(arguments$pattern, arguments$path %||% ".", arguments$context_lines %||% 2L),
    file_edit = tool_file_edit(arguments$file_path, arguments$old_string, arguments$new_string, arguments$replace_all),
    file_write = tool_file_write(arguments$file_path, arguments$content),
    install_package = tool_install_package(arguments$name),
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

  cat(cli::col_green(paste0("> ", trimws(code), "\n")))
  utils::flush.console()
  write_r_history(trimws(code))

  warnings_list <- list()
  output_lines <- character(0)

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
  MAX_CHARS <- 4000L
  if (nchar(output) > MAX_CHARS) {
    msg <- "\n... [output truncated]"
    output <- paste0(substr(output, 1, MAX_CHARS - nchar(msg)), msg)
  }

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
tool_read_file <- function(file_path) {
  if (is.null(file_path) || nchar(trimws(file_path)) == 0) {
    return("Error: No file path provided")
  }

  if (!file.exists(file_path)) {
    return(paste0("Error: File '", file_path, "' not found"))
  }

  content <- tryCatch(
    readLines(file_path, warn = FALSE),
    error = function(e) return(paste0("Error reading file: ", conditionMessage(e)))
  )

  if (length(content) > 200) {
    content <- c(content[1:200], paste0("... [", length(content) - 200, " more lines]"))
  }

  resolved <- normalizePath(file_path, mustWork = FALSE)
  agenticr_env$files_read[[resolved]] <- TRUE

  paste(content, collapse = "\n")
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
      fn <- getExportedValue(package, name)
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

  h <- tryCatch({
    if (is.null(package) || nchar(trimws(package)) == 0) {
      suppressWarnings(do.call(help, list(topic = name, help_type = "text")))
    } else {
      suppressWarnings(do.call(help, list(topic = name, package = package, help_type = "text")))
    }
  }, error = function(e) NULL)

  if (is.null(h) || length(h) == 0) {
    return(paste0("No documentation found for '", name, "'"))
  }

  help_lines <- character(0)
  con <- textConnection("help_lines", open = "w", local = TRUE)
  tryCatch({
    rd <- utils:::.getHelpFile(h)
    tools::Rd2txt(rd, out = con)
  }, error = function(e) {
    cat("Error:", conditionMessage(e), "\n", file = con)
  })
  close(con)

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
  if (!grepl("^[/~]", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  rg <- Sys.which("rg")
  if (nzchar(rg)) {
    cmd <- sprintf("rg --color=never -C %d %s %s 2>&1",
                   as.integer(context_lines), shQuote(pattern), shQuote(resolved))
  } else {
    cmd <- sprintf("grep -rnH --color=never %s %s 2>&1",
                   shQuote(pattern), shQuote(resolved))
  }

  out <- tryCatch(
    suppressWarnings(system(cmd, intern = TRUE, ignore.stderr = TRUE)),
    error = function(e) character(0)
  )

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
  if (!grepl("^[/~]", resolved)) {
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
  if (!grepl("^[/~]", resolved)) {
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
