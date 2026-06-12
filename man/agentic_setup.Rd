\name{agentic_setup}
\alias{agentic_setup}
\title{Interactive setup wizard}
\description{Walks the user through configuring an API key and provider interactively. Creates \verb{~/.agenticr/config.yml} if it does not exist.}
\usage{agentic_setup()}
\details{
The wizard prompts for API key, provider, and optional model override. Configuration is saved to \verb{~/.agenticr/config.yml} and can be edited manually later.
}
\value{Invisible.}
\examples{\dontrun{agentic_setup()}}
