#' Skills system — loadable prompt templates from ~/.agenticr/skills/
#'
#' Skills are stored as SKILL.md files in subdirectories of the skills
#' directory. Each skill is injected as a [Active skill: name] block
#' in the conversation context.
#'
#' Install a skill: agentic_install_skill("https://github.com/user/repo/skills/name/SKILL.md")
#'
#' @keywords internal

SKILLS_DIR <- file.path(Sys.getenv("HOME", unset = "~"), ".agenticr", "skills")

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
      skills[[name]] <- list(name = name, path = skill_file, content = content)
    }
  }
  skills
}

#' Get combined prompt blocks for all loaded skills
#'
#' @keywords internal
get_skill_prompts <- function() {
  skills <- load_skills()
  if (length(skills) == 0) return("")
  blocks <- character(0)
  for (s in skills) {
    blocks <- c(blocks, paste0(
      "[Active skill: ", s$name, "]\n",
      "Apply the following instructions:\n\n",
      s$content, "\n\n",
      "[/Active skill: ", s$name, "]"
    ))
  }
  paste(blocks, collapse = "\n\n")
}

#' Get prompts for only the currently active skills
#'
#' @keywords internal
get_active_skill_prompts <- function() {
  if (length(agenticr_env$active_skills) == 0) return("")
  all_skills <- load_skills()
  blocks <- character(0)
  for (name in names(agenticr_env$active_skills)) {
    s <- all_skills[[name]]
    if (is.null(s)) next
    blocks <- c(blocks, paste0(
      "[Active skill: ", s$name, "]\n",
      "Apply the following instructions:\n\n",
      s$content, "\n\n",
      "[/Active skill: ", s$name, "]"
    ))
  }
  paste(blocks, collapse = "\n\n")
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
