\name{agentic_config}
\alias{agentic_config}
\title{Read and manage configuration}
\description{See package documentation for details.}
\usage{agentic_config(..., save = FALSE)}
\arguments{
\item{...}{Named arguments to set}
\item{save}{If TRUE, save to config file}
}
\examples{
cfg <- agentic_config()
cat("Default provider:", cfg$provider, "\n")
}
