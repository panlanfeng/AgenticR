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
    install_package = tool_install_package(arguments$name),
    paste0("Unknown tool: ", tool_name)
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
