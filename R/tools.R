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
            path = list(
              type = "string",
              description = "Path to the file to read"
            )
          ),
          required = list("path")
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
          "Use this when unsure about a function's syntax or parameters."
        ),
        parameters = list(
          type = "object",
          properties = list(
            name = list(
              type = "string",
              description = "Name of the R function to look up"
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
          "If multiple matches exist, add more context lines to make it unique."
        ),
        parameters = list(
          type = "object",
          properties = list(
            path = list(
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
            )
          ),
          required = list("path", "old_string", "new_string")
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
            path = list(
              type = "string",
              description = "Path to the file to write"
            ),
            content = list(
              type = "string",
              description = "The full content to write to the file"
            )
          ),
          required = list("path", "content")
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

#' Execute a tool call and return the result
#'
#' @param tool_name Name of the tool to execute
#' @param arguments Named list of arguments
#' @return Character string with the result
#'
#' @keywords internal
execute_tool <- function(tool_name, arguments) {
  switch(
    tool_name,
    execute_r_code = tool_execute_r_code(arguments$code),
    get_dataframe_info = tool_get_dataframe_info(arguments$name),
    search_variables = tool_search_variables(arguments$pattern),
    read_file = tool_read_file(arguments$path),
    get_function_help = tool_get_function_help(arguments$name),
    grep_search = tool_grep_search(arguments$pattern, arguments$path, arguments$context_lines),
    file_edit = tool_file_edit(arguments$path, arguments$old_string, arguments$new_string),
    file_write = tool_file_write(arguments$path, arguments$content),
    install_package = tool_install_package(arguments$name),
    {
      if (startsWith(tool_name, "mcp_")) {
        mcp_execute_tool(tool_name, arguments)
      } else {
        paste0("Unknown tool: ", tool_name)
      }
    }
  )
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
  if (nchar(output) > 4000) {
    output <- paste0(substr(output, 1, 4000), "\n... [output truncated]")
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
tool_read_file <- function(path) {
  if (is.null(path) || !file.exists(path)) {
    return(paste0("Error: File '", path, "' not found"))
  }

  content <- tryCatch(
    readLines(path, warn = FALSE),
    error = function(e) return(paste0("Error reading file: ", conditionMessage(e)))
  )

  if (length(content) > 200) {
    content <- c(content[1:200], paste0("... [", length(content) - 200, " more lines]"))
  }

  if (length(content) > 2000) {
    content <- c(
      content[1:200],
      paste0("... [", length(content) - 200, " more lines]")
    )
  }

  paste(content, collapse = "\n")
}

#' Get R function documentation
#'
#' @keywords internal
tool_get_function_help <- function(name) {
  if (is.null(name) || nchar(trimws(name)) == 0) {
    return("Error: No function name provided")
  }

  old_pager <- getOption("pager")
  on.exit(options(pager = old_pager))
  options(pager = function(files, header, title, delete.file) {
    for (f in files) cat(paste(readLines(f), collapse = "\n"))
  })

  help_lines <- character(0)
  con <- textConnection("help_lines", open = "w", local = TRUE)
  sink(con)
  tryCatch(
    help(name, help_type = "text"),
    error = function(e) cat("Error:", conditionMessage(e))
  )
  sink()
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

#' Replace a unique string in a file
#'
#' @keywords internal
tool_file_edit <- function(path, old_string, new_string) {
  if (is.null(path) || nchar(trimws(path)) == 0) {
    return("Error: No file path provided")
  }
  if (is.null(old_string) || nchar(old_string) == 0) {
    return("Error: No old_string provided")
  }

  resolved <- path.expand(path)
  if (!grepl("^[/~]", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  if (!file.exists(resolved)) {
    return(paste0("File not found: ", resolved))
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
  if (count > 1) {
    return(paste0("Found ", count, " matches -- old_string must be unique. Provide more context to make it unique."))
  }

  new_content <- sub(old_string, new_string, content, fixed = TRUE)

  tryCatch(
    writeLines(new_content, resolved),
    error = function(e) return(paste0("Error writing file: ", conditionMessage(e)))
  )

  paste0("Replaced 1 occurrence in ", resolved)
}

#' Create or overwrite a file
#'
#' @keywords internal
tool_file_write <- function(path, content) {
  if (is.null(path) || nchar(trimws(path)) == 0) {
    return("Error: No file path provided")
  }
  if (is.null(content)) {
    content <- ""
  }

  resolved <- path.expand(path)
  if (!grepl("^[/~]", resolved)) {
    resolved <- file.path(getwd(), resolved)
  }

  dir_path <- dirname(resolved)
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  }

  tryCatch(
    writeLines(content, resolved),
    error = function(e) return(paste0("Error writing file: ", conditionMessage(e)))
  )

  size <- file.info(resolved)$size
  if (is.na(size)) size <- 0
  paste0("Wrote ", size, " bytes to ", resolved)
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
