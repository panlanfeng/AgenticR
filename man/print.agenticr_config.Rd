\name{print.agenticr_config}
\alias{print.agenticr_config}
\title{Print agenticr configuration}
\description{Pretty-prints the current agenticr configuration using cli formatting. Shows provider, model, temperature, max tokens, and API key status (masked).}
\usage{
\method{print}{agenticr_config}(x, ...)
}
\arguments{
\item{x}{An agenticr_config object (from \code{agentic_config()}).}
\item{...}{Additional arguments (ignored).}
}
\value{Invisibly returns \code{x}.}
\examples{\dontrun{agentic_config()}}
