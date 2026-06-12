\name{agentic_install_skill}
\alias{agentic_install_skill}
\title{Install a skill from a URL}
\description{Downloads a SKILL.md file from a URL and installs it to \verb{agenticr data directory}. Skills are opt-in prompt templates that modify agent behavior.}
\usage{agentic_install_skill(url, name = NULL)}
\arguments{
\item{url}{URL to the SKILL.md file (raw GitHub URL or similar).}
\item{name}{Skill name (optional; derived from URL if NULL).}
}
\value{Invisible.}
\examples{\dontrun{agentic_install_skill("https://raw.githubusercontent.com/user/skill/main/SKILL.md")}}
