# zsh-llm-assist

A Zsh plugin that brings the power of Large Language Models (LLMs) directly to your terminal. It helps you understand complex shell commands and generates commands from natural language descriptions.

[![asciicast](https://asciinema.org/a/766476.svg)](https://asciinema.org/a/766476)

## Features

-   **Explain Command (`Ctrl+X` `e`)**: Get a clear, plain-English explanation of the command currently in your buffer.
-   **Suggest Command (`Ctrl+X` `s`)**: Type what you want to do in natural language, and let the LLM replace it with the correct shell command.
-   **Multi-Provider Support**: Works with `copilot`, `gemini`, `claude`, and `codex` CLI tools.
-   **Non-Blocking UI**: Features a visual loading indicator ("Thinking...", "Suggesting...") that doesn't freeze your shell, powered by `zsh/zselect`.
-   **Persistent Output**: Explanations and errors are printed above your prompt so they don't vanish when you continue typing.

## Prerequisites

**IMPORTANT:** This plugin is a wrapper. It does **not** include an LLM engine itself. You **must** have one of the following CLI tools installed, authenticated, and available in your `$PATH` for this plugin to function:

-   **[Copilot CLI](https://github.com/github/gh-copilot)**: `gh copilot` (or standalone `copilot`)
-   **[Gemini CLI](https://github.com/google/gemini-cli)**: `gemini`
-   **[Claude Code](https://github.com/anthropics/claude-code)**: `claude`
-   **[Codex CLI](https://github.com/openai/codex-cli)**: `codex`

## Installation

### Oh My Zsh

1.  Clone this repository into your custom plugins directory:
    ```zsh
    git clone https://github.com/yourusername/zsh-llm-assist.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-llm-assist
    ```

2.  Add the plugin to the list of plugins in your `.zshrc`:
    ```zsh
    plugins=(... zsh-llm-assist)
    ```

3.  Restart your terminal or run `source ~/.zshrc`.

### Manual

1.  Clone the repository.
2.  Source the script in your `.zshrc`:
    ```zsh
    source /path/to/zsh-llm-assist/zsh-llm-assist.plugin.zsh
    ```

## Usage

### 1. Explain a Command
Type a command (or part of one) into your terminal, but **don't press Enter**.

Example buffer:
```zsh
tar -czf archive.tar.gz /path/to/folder
```

Press **`Ctrl+X` then `e`** (default).
The plugin will print an explanation above your prompt.

### 2. Suggest a Command
Type what you want to do in plain English.

Example buffer:
```text
find all python files modified yesterday and delete them
```

Press **`Ctrl+X` then `s`** (default).
The text will be replaced by the actual shell command (e.g., `find . -name "*.py" -mtime 1 -delete`).

## Configuration

You can configure the plugin by setting variables in your `.zshrc`.

### Select the LLM Tool
Choose which CLI tool to use. Default is `gemini`.

```zsh
export ZSH_LLM_CLI_TOOL="gemini" # Options: copilot, gemini, claude, codex
```

### Customizing Keyboard Shortcuts
The plugin binds `llm_explain` and `llm_suggest` to `Ctrl+X e` and `Ctrl+X s` by default. You can override these in your `.zshrc` **after** the plugin is loaded:

```zsh
# Use Ctrl+G for suggestions and Ctrl+E for explanations
bindkey '^G' llm_suggest
bindkey '^E' llm_explain
```

### Custom Models
Override the default models for specific tools:

```zsh
export ZSH_LLM_GEMINI_MODEL="gemini-1.5-pro"
export ZSH_LLM_CLAUDE_MODEL="claude-3-opus-20240229"
export ZSH_LLM_CODEX_MODEL="gpt-5.4-mini"
```

### Debug Mode
If things aren't working, enable debug mode to see the exact command being executed and any error messages.

```zsh
export ZSH_LLM_CLI_DEBUG=true
```

### Custom Binary Path
If your CLI tool is not in your `$PATH` or has a different name, you can specify the full path:

```zsh
export ZSH_LLM_BIN_PATH="/opt/bin/custom-gemini-cli"
```
*Note: If unset, it defaults to the value of `ZSH_LLM_CLI_TOOL`.*

## License

MIT
