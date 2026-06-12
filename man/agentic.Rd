\name{agentic}
\alias{agentic}
\title{Start an AgenticR session}
\description{Start an interactive AI-powered R console session. Type R code for direct execution, natural language for LLM processing, or slash commands for meta-operations. Press Ctrl+C twice to exit.}
\usage{agentic(auto = TRUE, ...)}
\arguments{
\item{auto}{If TRUE, tries to auto-configure from environment variables.}
\item{...}{Not used}
}
\details{
Valid R code executes directly with zero LLM overhead. Natural language queries are routed to the configured LLM provider, which generates and executes R code in the current session.

The \code{;} prefix forces natural language mode for any input (e.g. \code{;hist(mtcars[[\"mpg\"]])} sends it to the LLM instead of executing directly).
}
\value{Invisible. Called for its side effects.}
\examples{\dontrun{agentic()}}
