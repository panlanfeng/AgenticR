# CRAN submission notes for agenticr 0.3.1

## Test environments
- macOS (aarch64-apple-darwin23), R 4.6.0
- Windows (x86_64-w64-mingw32, Windows Server 2022), R 4.6.0 — via win-builder
- Linux (x86_64-unknown-linux-gnu), R 4.6.0

## R CMD check results
0 ERRORs | 0 WARNINGs | 1 NOTE

## Notes explained

### 1. New submission + package name spelling

First submission. "agenticr" is the intended package name (a portmanteau: "agentic" + "R"). Not a misspelling.

### 2. Interactive pager prevention via options()

The package prevents interactive pagers from blocking the headless agent session by
setting `options(pager = ..., help_type = "text", browser = ...)` during code execution
in `tool_execute_r_code()` and `tool_get_function_help()`. The custom pager writes output
to a temp file instead of launching an interactive viewer. Options are restored in
`on.exit()`. No functions are assigned to `.GlobalEnv` and no `attach()` is used.

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

### 5. Non-deterministic tests

Tests in `tests/testthat/test-llm.R` call live LLM APIs. They are guarded by
`skip_if_no_api()` (skips on CRAN machines which have no API key) and
`skip_on_cran()` for the two most non-deterministic tests. Unit tests
(125 tests in `test-agenticr.R`) are fully deterministic and cover
all core functionality without any API dependency.
