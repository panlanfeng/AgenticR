\name{agentic_config}
\alias{agentic_config}
\title{Read and manage configuration}
\description{Read, update, and persist agenticr configuration. Switching providers auto-loads the provider's defaults (model, base URL, context window).}
\usage{agentic_config(..., save = FALSE)}
\arguments{
\item{...}{Named arguments to set: \code{provider}, \code{api_key}, \code{api_base}, \code{api_model}, \code{temperature}, \code{max_tokens}, \code{reasoning_effort}, \code{max_turn_tokens}, \code{max_context_tokens}.}
\item{save}{If TRUE, save configuration to \verb{agenticr config file}.}
}
\details{
\code{reasoning_effort} controls DeepSeek's thinking depth. Valid values: \code{"minimal"}, \code{"low"}, \code{"medium"}, \code{"high"}. Default is \code{"medium"}.

When switching provider (e.g. \code{provider = "openai"}), the preset model and base URL are auto-loaded. Individual fields can be overridden.
}
\value{Invisibly returns the updated config list.}
\examples{
cfg <- agentic_config()
cat("Default provider:", cfg$provider, "\n")
}
