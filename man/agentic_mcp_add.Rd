\name{agentic_mcp_add}
\alias{agentic_mcp_add}
\title{Add an MCP server}
\description{See package documentation for details.}
\usage{agentic_mcp_add(name, command, args = character(0), env = list(), save = FALSE)}
\arguments{
\item{name}{Server name}
\item{command}{Command to run}
\item{args}{Command arguments}
\item{env}{Environment variables}
\item{save}{If TRUE, save to config}
}
\examples{\dontrun{agentic_mcp_add("search", "npx", args = c("-y", "mcp-server"))}}
