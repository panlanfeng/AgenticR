\name{agentic_resume}
\alias{agentic_resume}
\title{Resume a previous agentic session}
\description{Resume a previous agentic session from its turns.jsonl log file. Restores conversation history so the agent has full context of the prior session.}
\usage{agentic_resume(session_id, ...)}
\arguments{
\item{session_id}{Session ID (e.g. \code{"20250515_120000_a1b2c3d4"}). Use \code{agentic_sessions()} to list available IDs.}
\item{...}{Not used}
}
\value{Invisible. Starts the REPL with prior conversation restored.}
\examples{\dontrun{
agentic_sessions()
agentic_resume("20250515_120000_a1b2c3d4")
}}
