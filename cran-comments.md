# CRAN submission notes for agenticr 0.3.2

## Test environments
- macOS (aarch64-apple-darwin23), R 4.6.0
- Windows (x86_64-w64-mingw32, Windows Server 2022), R-devel — via win-builder
- Linux (x86_64-pc-linux-gnu), R-devel — via win-builder (Debian)
- Linux (x86_64-pc-linux-gnu), R 4.6.0 — via R-hub

## R CMD check results
0 ERRORs | 0 WARNINGs | 1 NOTE

## Notes explained

### 1. New submission + package name spelling

First submission. "agenticr" is the intended package name (a portmanteau: "agentic" + "R"). Not a misspelling.

### 2. Interactive pager prevention via options()

The package prevents interactive pagers from blocking the headless agent session by
setting `options(pager = ..., help_type = "text", browser = ...)` during code execution
in `tool_execute_r_code()` and `tool_get_function_help()`. The custom pager writes output
to a temp file instead of launching an interactive viewer. `on.exit(options(old_opts))`
is called on the very next line after `options(...)` to guarantee restoration even if
subsequent code throws. No functions are assigned to `.GlobalEnv`.

### 3. SystemRequirements: ripgrep (optional)

Ripgrep is listed as an optional system requirement for faster file search. When absent,
the package falls back to `grep` (if available) or a pure-R implementation using
`list.files()` + `readLines()` + `grep()` with full PCRE support. No functionality
is lost without ripgrep.

### 4. Data storage location

Agenticr stores persistent data (config, sessions, skills, memory) in the
platform-standard user data directory via `tools::R_user_dir("agenticr", "data")`.
This resolves to `~/Library/Application Support/agenticr/` on macOS,
`%APPDATA%/agenticr/` on Windows, and `~/.local/share/agenticr/` on Linux.
No writes occur without explicit user action. Config is only persisted with
`agentic_config(..., save = TRUE)`.

### 5. Console output via cat()

All `cat()` calls in the package are either interactive REPL display (tool results,
streaming output, slash commands), interactive setup prompts, or file writes to the
data directory via `cat(..., file = ...)`. No informational `cat()` output exists in
non-interactive library code. Comments marking interactive usage have been added.

### 6. Test variables in global environment

Two tests in `test-agenticr.R` temporarily add variables to `.GlobalEnv` to test the
`tool_get_dataframe_info` and `tool_search_variables` functions, which by design inspect
the global environment. Each assignment has a corresponding `on.exit(rm(...))` cleanup.
These are test-only operations that do not affect library code.

### 7. Non-deterministic tests

Tests in `tests/testthat/test-llm.R` call live LLM APIs. They are guarded by
`skip_if_no_api()` (skips on CRAN machines which have no API key) and
`skip_on_cran()` for the two most non-deterministic tests. Unit tests
(125 tests in `test-agenticr.R`) are fully deterministic and cover
all core functionality without any API dependency.

### 8. Bundled skill installation on .onLoad

The `.onLoad()` hook copies a bundled skill (`config-api`) from `inst/skills/` to the
user's skills directory via `tools::R_user_dir("agenticr", "data")/skills/`. This is
a one-time copy that only occurs if the skill does not already exist. No files are
written outside the platform-standard data directory.
