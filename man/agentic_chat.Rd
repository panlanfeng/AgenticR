\name{agentic_chat}
\alias{agentic_chat}
\title{Chat with the agent}
\description{Send a single natural language query to the LLM agent and get a response. Useful for programmatic use or one-off queries without entering the interactive REPL.}
\usage{agentic_chat(query)}
\arguments{
\item{query}{The natural language query string.}
}
\value{Invisible. Agent output is printed to the console.}
\examples{\dontrun{agentic_chat("what is the mean of mpg?")}}
