#' Skills system — loadable prompt templates from agenticr's skills directory
#'
#' Skills use YAML frontmatter. Only frontmatter fields are loaded into
#' the context. The full body is loaded on-demand via the load_skill_body tool.
#' Format:
#'   ---
#'   description: Short description of the skill
#'   trigger: When to apply this skill (optional hint for the model)
#'   ---
#'   # Full skill body (loaded only when needed)
#'
#' @keywords internal

SKILLS_DIR <- file.path(agenticr_dir(), "skills")

#' Parse YAML frontmatter from a SKILL.md file
#'
#' @keywords internal
parse_skill_frontmatter <- function(content, name) {
  pattern <- "^---\\s*\\n([\\s\\S]*?)---\\s*\\n?"
  match <- regexpr(pattern, content, perl = TRUE)
  if (match == -1) {
    return(list(
      name = name,
      description = "",
      trigger = "",
      body = content
    ))
  }
  cap_start <- attr(match, "capture.start")[1, 1]
  cap_len <- attr(match, "capture.length")[1, 1]
  frontmatter_text <- substr(content, cap_start, cap_start + cap_len - 1)
  body <- substr(content, cap_start + cap_len + 4, nchar(content))
  body <- trimws(body)

  fm <- tryCatch(
    yaml::yaml.load(frontmatter_text, eval.expr = FALSE),
    error = function(e) list()
  )
  list(
    name = name,
    description = fm$description %||% "",
    trigger = fm$trigger %||% "",
    body = body
  )
}

#' Load all skills from the skills directory
#'
#' @keywords internal
load_skills <- function() {
  dir.create(SKILLS_DIR, showWarnings = FALSE, recursive = TRUE)
  skills <- list()
  for (d in list.dirs(SKILLS_DIR, recursive = FALSE, full.names = TRUE)) {
    skill_file <- file.path(d, "SKILL.md")
    if (!file.exists(skill_file)) next
    name <- basename(d)
    content <- tryCatch(
      paste(readLines(skill_file, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    if (nchar(trimws(content)) > 0) {
      skills[[name]] <- parse_skill_frontmatter(content, name)
    }
  }
  skills
}

#' Get frontmatter-only prompts for active skills
#'
#' @keywords internal
get_active_skill_prompts <- function() {
  if (length(agenticr_env$active_skills) == 0) return("")
  all_skills <- load_skills()
  blocks <- character(0)
  for (name in names(agenticr_env$active_skills)) {
    s <- all_skills[[name]]
    if (is.null(s)) next
    desc <- s$description
    trigger <- s$trigger
    line <- paste0(
      "[Available skill: ", s$name, "]\n",
      "description: ", if (nchar(desc) > 0) desc else "(no description)",
      if (nchar(trigger) > 0) paste0("\ntrigger: ", trigger) else "",
      "\n[Use load_skill_body to read full instructions]"
    )
    blocks <- c(blocks, line)
  }
  paste(blocks, collapse = "\n\n")
}

#' Load the full body of a skill for the LLM
#'
#' @param name Skill name
#' @return Full skill body text
#' @keywords internal
tool_load_skill_body <- function(name) {
  all_skills <- load_skills()
  s <- all_skills[[name]]
  if (is.null(s)) {
    return(paste0("Skill '", name, "' not found. Use agentic_skills() to list installed skills."))
  }
  if (nchar(s$body) == 0) {
    return(paste0("Skill '", name, "' has no body content."))
  }
  result <- paste0("[Skill: ", s$name, "]\n", s$body, "\n[/Skill: ", s$name, "]")

  skill_dir <- file.path(agenticr_dir(), "skills", name)
  mem_file <- file.path(skill_dir, "MEMORY.md")
  if (file.exists(mem_file)) {
    mem_content <- tryCatch(
      paste(readLines(mem_file, warn = FALSE), collapse = "\n"),
      error = function(e) ""
    )
    if (nchar(trimws(mem_content)) > 0) {
      result <- paste0(result, "\n\n[Skill memory for: ", s$name, "]\n", mem_content)
    }
  }
  result
}

#' Install a skill from a URL
#'
#' Downloads a SKILL.md file from a URL and saves it to the skills directory.
#' The skill name is derived from the last directory in the URL path.
#'
#' @param url URL to the SKILL.md file
#' @param name Skill name (optional, derived from URL if not provided)
#' @export
agentic_install_skill <- function(url, name = NULL) {
  if (is.null(name)) {
    parts <- strsplit(url, "/")[[1]]
    parent <- if (length(parts) >= 2) parts[length(parts) - 1] else "skill"
    name <- parent
  }

  skill_dir <- file.path(SKILLS_DIR, name)
  dir.create(skill_dir, showWarnings = FALSE, recursive = TRUE)
  skill_file <- file.path(skill_dir, "SKILL.md")

  cli::cli_alert_info("Downloading skill '{name}' from {.url {url}}...")
  content <- tryCatch(
    httr::GET(url, httr::timeout(30)),
    error = function(e) return(NULL)
  )
  if (is.null(content) || httr::status_code(content) >= 400) {
    cli::cli_alert_danger("Failed to download skill: HTTP {if(is.null(content)) 'error' else httr::status_code(content)}")
    return(invisible(FALSE))
  }

  text <- httr::content(content, "text", encoding = "UTF-8")
  writeLines(text, skill_file)
  cli::cli_alert_success("Skill '{name}' installed to {.file {skill_file}}")
  cli::cli_text("The skill will be active on next agentic session.")
  invisible(TRUE)
}

#' List installed skills
#'
#' @export
agentic_skills <- function() {
  skills <- load_skills()
  if (length(skills) == 0) {
    cli::cli_alert_info("No skills installed. Use agentic_install_skill(url) to add one.")
    return(invisible())
  }
  cli::cli_h2("Installed Skills")
  for (s in skills) {
    cli::cli_li("{.val {s$name}} ({nchar(s$content)} bytes)")
  }
  invisible()
}
