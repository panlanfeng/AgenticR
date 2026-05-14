# AgenticR - AI-Powered R Console Assistant

Type natural language or incorrect R code directly in the R console. AgenticR routes natural language to an LLM agent that generates and executes R code in the current session.

## Installation

```r
# Install from source
install.packages("remotes")
remotes::install_local("path/to/agenticr")
```

## Quick Start

```r
library(agenticr)

# 1. Configure your API key (DeepSeek, OpenAI, or compatible)
agentic_config(api_key = "sk-your-key-here", save = TRUE)

# 2. Start the AI-assisted session
agentic()
```

Inside the agentic session, type:
- **R code** - executed directly with zero latency
- **Natural language** - routed to the LLM agent for processing
- **`/help`** - show available commands
- **`/clear`** - clear conversation history
- **`exit()`** or **Ctrl+C** - quit agentic mode

## Configuration

Three ways to configure:

1. **Environment variables**:
   ```bash
   export AGENTICR_API_KEY="sk-..."
   export AGENTICR_API_BASE="https://api.deepseek.com/v1"
   export AGENTICR_MODEL="deepseek-chat"
   ```

2. **Config file** (`~/.agenticr/config.yml`):
   ```yaml
   api_key: "sk-..."
   api_base: "https://api.deepseek.com/v1"
   api_model: "deepseek-chat"
   ```

3. **In-session**:
   ```r
   agentic_config(api_key = "sk-...", save = TRUE)
   ```

### Supported Providers

| Provider | api_base | api_model |
|----------|----------|-----------|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o`, `gpt-4` |
| Custom | `https://your-endpoint/v1` | your-model-name |

## Features

### Natural Language Processing
Type questions in plain English and get R code executed automatically:
```
[agentic] > what is the average mpg for 8-cylinder cars?
[agentic] > make a scatter plot of mpg vs hp colored by cyl
[agentic] > run a t-test comparing mpg between 4 and 8 cylinder groups
```

### Direct R Code Execution
Valid R code is executed directly without LLM overhead:
```
[agentic] > mean(mtcars$mpg)
[agentic] > library(ggplot2)
```

### Error Interceptor
Enable automatic processing of errors at the standard `>` prompt:
```r
agentic_enable()
> make a plot of mpg vs hp  # automatically processed by AgenticR
```

### One-Shot Queries
Process a single query without entering REPL mode:
```r
agentic_process("what is the correlation between mpg and hp in mtcars?")
```

### Conversation History
Agent maintains context between turns for multi-step analysis.

## Available Tools

The LLM agent has access to these tools:
- **execute_r_code** - Run R code in the current session
- **get_dataframe_info** - Inspect dataframe structure
- **search_variables** - Find variables by name pattern
- **read_file** - Read file contents
- **install_package** - Request package installation

## RStudio Integration

Add to your `.Rprofile` to auto-start AgenticR when RStudio opens:
```r
if (interactive()) {
  library(agenticr)
  agentic()
}
```

## License

MIT
