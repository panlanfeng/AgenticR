# CRAN submission notes for agenticr 0.3.3

## Resubmission notes

This is a resubmission. The previous submission received feedback:
1. Missing `\value` tags — **fixed**: all 15 exported function Rd files now have `\value` tags.
2. `.GlobalEnv` modification — **resolved with reviewer**: the reviewer confirmed that `eval(expr, envir = .GlobalEnv)` for user-requested code execution in this interactive package is acceptable, per the CRAN Cookbook's exception for interactive tools like Shiny. All previous `assign(..., envir = .GlobalEnv)` calls were removed.

## Test environments
- macOS (aarch64-apple-darwin23), R 4.6.0
- Linux (x86_64-pc-linux-gnu), R-devel (r90185), Ubuntu 24.04 — via R-hub Actions
- Windows (x86_64-w64-mingw32), R-devel (r90277), Windows Server 2022 — via R-hub Actions

## R CMD check results
macOS:    0 ERRORs | 0 WARNINGs | 1 NOTE (New submission)
Linux:    0 ERRORs | 0 WARNINGs | 0 NOTEs
Windows:  0 ERRORs | 0 WARNINGs | 0 NOTEs

All checks run with full `--as-cran` (including PDF/HTML manual validation).

## Notes explained

### 1. New submission

First submission. "agenticr" is the intended package name (a portmanteau: "agentic" + "R"). Not a misspelling.

### 2. SystemRequirements: ripgrep (optional)

Ripgrep is listed as an optional system requirement for faster file search. When absent, the package falls back to `grep` (if available) or a pure-R implementation using `list.files()` + `readLines()` + `grep()` with full PCRE support. No functionality is lost without ripgrep.

### 3. Data storage via tools::R_user_dir()

Agenticr stores persistent data (config, sessions, skills, memory) in the platform-standard user data directory via `tools::R_user_dir("agenticr", "data")`. This resolves to `~/Library/Application Support/agenticr/` on macOS, `%APPDATA%/agenticr/` on Windows, and `~/.local/share/agenticr/` on Linux. No writes occur without explicit user action. Config is only persisted with `agentic_config(..., save = TRUE)`.

### 4. Interactive pager prevention via options()

The package prevents interactive pagers from blocking the agent session by setting `options(pager = ..., help_type = "text", browser = ...)` during code execution in `tool_execute_r_code()` and `tool_get_function_help()`. `on.exit(options(old_opts))` is called immediately after to guarantee restoration. No functions are assigned to `.GlobalEnv`.

### 5. Bundled skill installation on .onLoad

The `.onLoad()` hook copies a bundled skill (`config-api`) from `inst/skills/` to the user's skills directory via `tools::R_user_dir()/skills/`. This is a one-time copy that only occurs if the skill does not already exist.

### 6. Non-deterministic tests

Tests in `tests/testthat/test-llm.R` call live LLM APIs. They are guarded by `skip_if_no_api()` (skips on CRAN machines which have no API key) and `skip_on_cran()` for the most non-deterministic tests. Unit tests in `test-agenticr.R` are fully deterministic and cover all core functionality without any API dependency.
