\name{agentic_mcp_add}
\alias{agentic_mcp_add}
\title{Add an MCP server}
\description{Connect to an external Model Context Protocol (MCP) server via JSON-RPC over stdio. Tools from the server are merged into the agent's tool list.}
\usage{agentic_mcp_add(name, command, args = character(0), env = list(), save = FALSE)}
\arguments{
\item{name}{Server name for display and tool prefixing (e.g. \code{"filesystem"}).}
\item{command}{Executable to run (e.g. \code{"npx"}, \code{"node"}, \code{"python"}).}
\item{args}{Command-line arguments.}
\item{env}{Environment variables as a named list.}
\item{save}{If TRUE, persist the server config to \verb{agenticr config file}.}
}
\value{Invisible.}
\examples{\dontrun{agentic_mcp_add("search", "npx", args = c("-y", "mcp-server"))}}
