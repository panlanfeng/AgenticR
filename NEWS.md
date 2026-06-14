# agenticr 0.3.1

- Per-provider max_tokens defaults (auto-set when switching providers)
- agentic_setup() wizard now asks for max output tokens
- Custom model and max_tokens preserved when re-selecting the same provider
- reasoning_effort and api_key no longer leak across provider switches
- Eliminated CRAN NOTE for global assignments by using options()-only pager control
- Fixed MCP server connection (processx API compatibility, JSON-RPC id type)
- MCP capabilities now sent as {} instead of []
- Fixed get_function_help tool blocking on interactive pager
- Fixed help() and ? blocking in tool_execute_r_code via pager option
- Exclude editor/IDE folders from tarball and git
- Updated config template and documentation

# agenticr 0.3.0

- Initial release
- AI-powered R console assistant with natural language interface
- Supports DeepSeek, OpenAI, and compatible LLM providers
- REPL mode and error-interceptor mode
- Tool framework: `read_file`, `list_files`, `execute_r_code`, `memory_write`, task management
- Skill system with anthropic-style frontmatter loading
- MCP server support
- CRAN-ready
