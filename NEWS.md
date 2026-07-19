# agenticr 0.3.3

- CRAN compliance: added missing `\value` tags to 6 Rd files
- CRAN compliance: switched from `~/.agenticr/` to `tools::R_user_dir()` for data storage
- CRAN compliance: removed `assign(.GlobalEnv)` monkey-patching (reviewer confirmed `eval(.GlobalEnv)` is acceptable for interactive tools)
- CRAN compliance: added `SystemRequirements` and `cran-comments.md`
- Fixed `agentic_skills()` showing `NA` bytes
- Fixed `agentic_enable()` cli formatting crash when no API key configured
- Removed dead code: `write_turn_history()`, orphan roxygen, unused MCP fields, `todos`
- Replaced `getExportedValue()` (always errored) with `getFromNamespace()`
- Pure-R grep fallback when neither `rg` nor `grep` is available
- Windows cross-platform fixes: `Sys.chmod()`, `rc.settings()`, path regex, `findstr` fallback

# agenticr 0.3.2

- Default provider is now local (Ollama Qwen3-1.7B) — zero config needed
- First-run auto-detection: if no API key, offers to install Ollama automatically
  with platform-specific commands (brew/curl|sh/winget)
- `/provider` and `/model` slash commands for switching providers and models mid-session
- `agentic_config()` renamed params: `api_base` → `base_url`, `api_model` → `model`
  (old names accepted for backward compat)
- Per-provider max_tokens defaults with fallback in setup wizard
- Bundled `config-api` skill with provider reference data and doc URLs
- LLM tests: 100% pass rate against local Qwen3-1.7B model
- Test improvements: agent-loop tests for multi-step queries, explicit fail guards
  on all if/else branches, removed unreasonable "fix mtcar typo" test

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
