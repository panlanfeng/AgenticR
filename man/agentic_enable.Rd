\name{agentic_enable}
\alias{agentic_enable}
\title{Enable error interceptor}
\description{See package documentation for details.}
\value{No return value, called for side effects.}
\usage{agentic_enable(auto_process = TRUE)}
\arguments{
\item{auto_process}{If TRUE, processes NL errors with the LLM agent.}
}
\examples{
agentic_enable()
# Normal R code runs directly without involving the LLM
mean(1:10)
agentic_disable()
}
