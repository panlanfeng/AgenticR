# AgenticR — Turn R console into AI Agent

Rethink about coding console and AI agent UI. Their user experiences are so similar. Do we really need two separte places, one for code and and one for LLM instructions? Isolating the two causes context loss for agent. AI is smart enough to know what should goes to LLM and what should go to interpretor.

How about an AI agent directly live in R console. Uers type natural langauge or R code in the R console directly, no mode switch, no llm overhead. That's why I want to bring AgenticR. AgenticR auto detects your intention: it executes R code in the console normal with no LLM overhead; it routes natural languages to the AI agent. 


```r
> library(agenticr); agentic()
> load mtcars  # this will run `data(mtcars)`
> mean of mpg by cylinder in mtcars, then make a bar chart
# Agent inspects the data, computes group means, creates a ggplot2 chart.

> mtcars | group by wt | mean(x) for x in (carb, gear, am) # agenticR translates bad grammar into legitimate code
        > library(dplyr)
        mtcars |>
        group_by(wt) |>
        summarise(across(c(carb, gear, am), mean))


> mtcars | gg_point(mpg, wt) + hline(y=wt), facet by cyl  # no need to remember the long list of function names

> load mtcars and write a shiny app to visualize the data # it will build and run the shinyApp

> plot(mtcars$mpg, mtcars$wt) # normal R code executes normally with no llm overhead

```



## Installation

```r
# Install from GitHub
install.packages("remotes")
remotes::install_github("panlanfeng/AgenticR")
```

Or build from source: `R CMD build . && R CMD INSTALL agenticr_0.1.0.tar.gz`

## Quick Start

```r
library(agenticr)

# One-time setup (interactive wizard)
agentic_setup() # or directly config it in the ~/.agenticr/config.yml

# Start the AI-assisted session
agentic()
```

At the prompt, type R code, natural language, or slash commands. Type `exit()` or press Ctrl+C to quit.

### One-line setup with a provider

```r
library(agenticr)
agentic_config(provider = "deepseek")  # auto-detects DEEPSEEK_API_KEY env var
agentic()
```

## Configuration

### Environment Variables (auto-detected)

Set any of these env vars and AgenticR auto-detects the provider:

```bash
#any one of the following will work
export DEEPSEEK_API_KEY="sk-..."
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-..."
export GOOGLE_API_KEY="..."
export GLM_API_KEY="..."
export KIMI_API_KEY="..."
# ... (see agentic_providers() for full list)
```

### One-command provider switch

```r
agentic_config(provider = "deepseek")
agentic_config(provider = "openai")
agentic_config(provider = "anthropic")
agentic_config(provider = "glm")
```

### Config file (`~/.agenticr/config.yml`)

```yaml
provider: "deepseek"
api_key: "sk-..."
api_base: "https://api.deepseek.com"
api_model: "deepseek-v4-pro"
temperature: 0.1
max_tokens: 4096
max_rounds: 10
```

### In-session

```r
agentic_config(api_key = "sk-...", save = TRUE)
agentic_config(temperature = 0.0)  # deterministic output
```


## Features

### AI-Powered REPL

```
> mean of mpg by cylinder in mtcars?
> head(mtcars)
                   mpg cyl disp  hp drat    wt  qsec vs am gear carb
Mazda RX4         21.0   6  160 110 3.90 2.620 16.46  0  1    4    4
Agent response:
Mean MPG: 4-cyl 26.7, 6-cyl 19.7, 8-cyl 15.1
```

### Direct R code execution (zero latency)

Valid R code is executed directly — parsed and evaluated in the current session with no LLM call. Assignment creates persistent variables, plots render in the Plots pane.

### Error interceptor

`agentic_enable()` hooks into R's error handler. Natural language typed at the standard `>` prompt that causes an error is automatically routed to the agent.

### Agent tools

| Tool | Purpose |
|------|---------|
| `execute_r_code` | Run R code in the current session |
| `get_dataframe_info` | Inspect dataframe structure (cols, types, preview) |
| `search_variables` | Find variables by name pattern |
| `read_file` | Read file contents |
| `get_function_help` | Look up R function documentation |
| `grep_search` | Search files with ripgrep or grep |
| `file_edit` | Replace a unique string in a file |
| `file_write` | Create or overwrite a file |
| `install_package` | Request CRAN package installation (user-confirmed) |

### Skills (opt-in prompt templates)

Install skills from URLs. Activate them explicitly with `/skill <name>`. Skills inject behavior instructions into the agent's context.

```r
# Install from GitHub
agentic_install_skill("https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grill-me/SKILL.md")

# In the REPL, activate when needed
> /skill grill-me
```

Skills are stored in `~/.agenticr/skills/<name>/SKILL.md`. Deactivate with `/skill:off <name>`.

### MCP (Model Context Protocol)

Connect external tool servers via JSON-RPC over stdio. MCP tools are merged into the agent's tool list with `mcp_<server>_<tool>` names.

```r
agentic_mcp_add("filesystem", "npx",
  args = c("-y", "@anthropic/mcp-filesystem", "/path"),
  save = TRUE)
```

Or configure in `~/.agenticr/config.yml`:

```yaml
mcp_servers:
  filesystem:
    command: npx
    args: ["-y", "@anthropic/mcp-filesystem", "/path"]
```


### Conversation memory

At 50K tokens of session growth, a sub-agent extracts persistent memory to `~/.agenticr/MEMORY.md`: user profile, environment learnings, feedback, and project context. The file path is mentioned in stable context — the agent can `read_file` it when needed.

### AGENTS.md

Place `~/.agenticr/AGENTS.md` (global) or `./AGENTS.md` (project) files to inject custom instructions into every agentic session. Combine with skills for layered customization:

```
# ~/.agenticr/AGENTS.md
Always use base R graphics instead of ggplot2.
Prefer data.table over dplyr for large datasets.
```

## REPL Commands

| Command | Action |
|---------|--------|
| `/help` | Show available commands |
| `/config` | Show current configuration |
| `/clear` | Clear conversation history |
| `/vars` | List variables in global environment |
| `/info <name>` | Show dataframe structure |
| `/skill <name>` | Activate a skill for this session |
| `/skill:off <name>` | Deactivate a skill |
| `/skills` | List installed skills |
| `/mcp` | Show connected MCP servers |
| `exit()` or Ctrl+C | Quit agentic session |



## Architecture

```
User types input at prompt
        │
        ▼
read_complete_input() ← handles multi-line pipes, continuation
        │
        ▼
is_natural_language() ← R indicators → R parser → NL heuristics
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
   │    loop until done or token budget exceeded
   │
   └──────→ back to prompt
```


## License

MIT
