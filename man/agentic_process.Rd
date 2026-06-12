\name{agentic_process}
\alias{agentic_process}
\title{Process a single natural language query}
\description{Internal function that processes a query through the agent loop. This is what the error interceptor calls when it detects natural language input.}
\usage{agentic_process(query)}
\arguments{
\item{query}{The natural language query to process.}
}
\value{Invisible. Results are printed to the console.}
\examples{\dontrun{agentic_process("what is 2+2?")}}
