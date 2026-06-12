# CRAN submission notes for agenticr 0.3.0

## Test environments
- macOS (aarch64-apple-darwin23), R 4.6.0
- Windows (x86_64-w64-mingw32, Windows Server 2022), R 4.6.0 — via win-builder

## R CMD check results
0 ERRORs | 0 WARNINGs | 2 NOTEs

## Notes explained

### 1. New submission + package name spelling

First submission. "agenticr" is the intended package name (a portmanteau: "agentic" + "R"). Not a misspelling.

### 2. Assignments to global environment

The package monkey-patches `help()`, `help.search()`, `?`, and `View()` in `.GlobalEnv` during
`agentic_enable()` and restores them on `agentic_disable()`. This is the error-interceptor
mechanism: when a user types natural language at the R console, it triggers an error which
the interceptor routes to the LLM agent. The assignments are scoped to the interceptor
lifetime and fully restored. This design is analogous to how `debugger.lines` and other
R debugging tools modify the global error handler.

### 3. SystemRequirements: ripgrep (optional)

Ripgrep is listed as an optional system requirement for faster file search. When absent,
the package falls back to `grep` (if available) or a pure-R implementation using
`list.files()` + `readLines()` + `grep()` with full PCRE support. No functionality
is lost without ripgrep.

### 4. Writes to home directory (~/.agenticr/)

`save_config()` creates `~/.agenticr/` for persistent configuration storage.
This only runs when the user explicitly calls `agentic_config(..., save = TRUE)`.
All other state (session logs, history, memory) uses per-session temp directories.

### 5. Non-deterministic tests

Tests in `tests/testthat/test-llm.R` call live LLM APIs. They are guarded by
`skip_if_no_api()` (skips on CRAN machines which have no API key) and
`skip_on_cran()` for the two most non-deterministic tests. Unit tests
(61 tests in `test-agenticr.R`) are fully deterministic and cover
all core functionality without any API dependency.
