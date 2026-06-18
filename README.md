# AgenticR — AI Agent in Your R Console

Rethink about R console and AI agent UI. Their user experiences are so similar. Do we really need two separate places, one for code and one for LLM instructions? Isolating the two causes context loss for the agent. AI is smart enough to know what should go to LLM and what should go to the interpreter.

AgenticR lets an AI agent live directly in your R console. Type natural language or R code in the same prompt — no mode switch, no LLM overhead for normal code. AgenticR auto-detects your intention: R code executes directly; natural language routes to the AI agent.

## Key Features

- **Zero-config local model** — if no API key, uses Ollama + Qwen3-1.7B automatically
- **Zero-overhead R execution** — valid R code runs directly, no LLM round-trip
- **Any grammar** — type R, pseudo-code, or plain English; agenticr figures it out
- **16 provider presets** with auto-detection from environment variables
- **Agent tools** — R execution, file read/write/edit, repo search, data inspection
- **Skills system** — installable prompt templates from URLs
- **MCP support** — connect external tool servers via Model Context Protocol
- **Error interceptor** — works in standard R console, not just the REPL
- **Context-aware** — knows what code you ran, tracks conversation, auto-memory
- **Streaming** — real-time token streaming with prompt cache optimization
- **Per-session history** — command history scoped to each agentic session

## Installation

```r
# Install from GitHub
install.packages("remotes")
remotes::install_github("panlanfeng/AgenticR")
```

Or build from source: `R CMD build . && R CMD INSTALL agenticr_0.3.2.tar.gz`

## Quick Start

### Zero-config — runs without an API token

AgenticR works out of the box with no API key. It uses a locally hosted
**Qwen3 1.7B** model via **Ollama** with full tool-calling support:

```r
library(agenticr)
agentic()  # Starts immediately if Ollama is running
```

On first run, agenticr will offer to install Ollama and download the Qwen3 1.7B
model (~1.4GB download, one-time). Once set up, you have a fully capable AI agent
running entirely on your machine — no API token required.

### With an API key

```r
library(agenticr)

# One-time setup (interactive wizard)
agentic_setup()

# Or configure directly with full parameters
agentic_config(
  provider = "deepseek",
  model = "deepseek-v4-pro",
  base_url = "https://api.deepseek.com",
  api_key = "sk-...",
  max_tokens = 32768,
  reasoning_effort = "medium",   # minimal|low|medium|high
  temperature = 0.1,
  max_turn_tokens = 64000,
  max_context_tokens = 1048576
)

# Start AI-assisted session
agentic()
```

At the prompt, type R code, natural language, or slash commands. Press Ctrl+C or Ctrl+D twice to exit.

### One-line setup with a provider

```r
library(agenticr)
agentic_config(provider = "deepseek")  # auto-detects DEEPSEEK_API_KEY, uses preset defaults
agentic()
```

### Switch between providers and models mid-session

```r
> /provider            # list all providers with key status
> /provider openai     # switch to OpenAI
> /model               # show current model
> /model gpt-4.1       # change model for current provider
> /provider local      # switch back to local Ollama model
```

### Run a single query

```r
agentic_chat("mean of mpg by cylinder in mtcars")
agentic_process("load iris and create a histogram of Sepal.Length")
```

## Configuration

### Environment Variables (auto-detected)

Set any of these env vars — AgenticR auto-detects the provider:

```bash
export DEEPSEEK_API_KEY="sk-..."
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
export GLM_API_KEY="..."
export KIMI_API_KEY="..."
export MISTRAL_API_KEY="..."
export QWEN_API_KEY="..."
# ... see agentic_providers() for full list
```

### Provider switch

```r
agentic_config(provider = "deepseek", model = "deepseek-v4-pro")
agentic_config(provider = "deepseek", reasoning_effort = "high")  # minimal|low|medium|high
agentic_config(provider = "openai", model = "gpt-5.5")
agentic_config(provider = "anthropic", model = "claude-opus-4-7")
agentic_config(provider = "glm", model = "glm-5.1")
agentic_config(provider = "kimi", model = "kimi-k2-thinking")
agentic_config(provider = "siliconflow", model = "deepseek-ai/DeepSeek-V4-Flash")
```

### Config file

Config is stored in agenticr's data directory (platform-specific: `~/Library/Application Support/agenticr/` on macOS, `%APPDATA%/agenticr/` on Windows, `~/.local/share/agenticr/` on Linux):

```yaml
provider: "deepseek"
api_key: "sk-..."
base_url: "https://api.deepseek.com"
model: "deepseek-v4-pro"
temperature: 0.1
max_tokens: 32768
max_turn_tokens: 64000
reasoning_effort: "medium"  # deepseek: minimal, low, medium, high
```

### In-session

```r
agentic_config(api_key = "sk-...", save = TRUE)
agentic_config(temperature = 0.0)  # deterministic output
```

## Agent Tools

| Tool | Purpose |
|------|---------|
| `execute_r_code` | Run R code in the current session |
| `get_dataframe_info` | Inspect dataframe structure (cols, types, preview) |
| `search_variables` | Find variables by name pattern |
| `read_file` | Read file contents (with line numbers, pattern search, large-file guard) |
| `list_files` | List files in a directory, ignoring VCS and build artifacts |
| `get_function_help` | Look up R function documentation |
| `grep_search` | Search files by content (uses ripgrep, grep, or pure-R fallback) |
| `file_edit` | Replace a unique string in a file |
| `file_write` | Create or overwrite a file |
| `task_write` | Create and maintain structured task lists |
| `task_update` | Update task status |
| `memory_write` | Write to persistent session memory |

## REPL Commands

| Command | Action |
|---------|--------|
| `;` prefix | Force natural language mode for this input |
| `/help` | Show available commands |
| `/config` | Show current configuration |
| `/provider` | List or switch LLM provider (`/provider anthropic`) |
| `/model` | Show or change model name (`/model gpt-4.1`) |
| `/clear` | Clear conversation history |
| `/vars` | List variables in global environment |
| `/info <name>` | Show dataframe structure |
| `/skill <name>` | Activate a skill for this session |
| `/skill:off <name>` | Deactivate a skill |
| `/skills` | List installed skills |
| `/mcp` | Show connected MCP servers |
| `exit()` or Ctrl+C twice | Quit agentic session |

## Session Management

```r
# Resume a previous session
agentic_sessions()                            # list available sessions
agentic_resume("20250515_120000_a1b2c3d4")    # resume by ID
```

## Skills (opt-in prompt templates)

AgenticR includes a bundled `config-api` skill that guides users through API setup
with provider detection, model defaults, and documentation references. Activate it
with `/skill config-api`.

Additional skills can be installed from URLs:

```r
agentic_install_skill("https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grill-me/SKILL.md")

# In the REPL, activate when needed
> /skill grill-me
```

Skills are stored in agenticr's skills directory. Deactivate with `/skill:off <name>`.

## MCP (Model Context Protocol)

Connect external tool servers via JSON-RPC over stdio.

```r
agentic_mcp_add("filesystem", "npx",
  args = c("-y", "@anthropic/mcp-filesystem", "/path"),
  save = TRUE)
```

Or configure in the config file:

```yaml
mcp_servers:
  filesystem:
    command: npx
    args: ["-y", "@anthropic/mcp-filesystem", "/path"]
```

## Memory System

AgenticR builds a memory file in its data directory, indexing session learnings.
The agent automatically records insights across sessions.

## Architecture

```
User types input at prompt
        │
        ▼
read_complete_input() ← handles multi-line pipes, continuation
        │
        ▼
is_natural_language() ← R indicators → parser → NL heuristics
        │
   ┌────┴────┐
   ▼         ▼
R code    NL query
   │         │
parse()   process_with_agent()
eval()      │
print()     ▼
   │    build messages (stable prefix + conversation + tools)
   │    chat_completion_stream() ← token-by-token streaming
   │    process tool_calls / inline code blocks
   │    execute in current R session
   │    display results
   │    loop until done or token budget exhausted
   │
   └──────→ back to prompt
```

## License

MIT
