# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

zmodload zsh/zselect

# 1. Select the tool to use: "codex", "claude", "gemini", "opencode" or "copilot"
: ${ZSH_LLM_CLI_TOOL:="gemini"}

# 2. Path to binary (Optional override)
# If unset, the plugin will use the value of ZSH_LLM_CLI_TOOL dynamically.
# : ${ZSH_LLM_BIN_PATH:="$ZSH_LLM_CLI_TOOL"}

# 3. Debug Mode (default: false)
: ${ZSH_LLM_CLI_DEBUG:=false}

# 4. Default Models (User Configurable)
# You can override these in your .zshrc
: ${ZSH_LLM_GEMINI_MODEL:="gemini-3-flash-preview"}
: ${ZSH_LLM_CLAUDE_MODEL:="claude-haiku-4-5"}
: ${ZSH_LLM_CODEX_MODEL:="gpt-5.1-codex-mini"}
: ${ZSH_LLM_COPILOT_MODEL:="claude-haiku-4.5"}
: ${ZSH_LLM_OPENCODE_MODEL:="xai/grok-code-fast-1"}

# ------------------------------------------------------------------------------
# System Prompts (Bulletproofed)
# ------------------------------------------------------------------------------

_llm_prompt_explain="You are a Zsh expert helper. Your goal is to explain what a specific shell command does. Rules: 1. Keep the explanation between 2 to 4 sentences. 2. Be clear and plain-spoken. 3. Do not repeat the command, just explain its effect. 4. Do not use Markdown formatting. Command to explain:"

_llm_prompt_suggest="You are a Zsh command generator. Return ONLY the raw command string required to fulfill the user request. Rules: 0. No tool usage or extra thinking. 1. Output MUST be a valid executable Zsh command. 2. NO markdown formatting (no backticks). 3. NO explanatory text. 4. NO leading/trailing whitespace. 5. If multiple steps are needed, chain them with && or ;. Request:"

# ------------------------------------------------------------------------------
# Helpers: Loader & Sanitizer
# ------------------------------------------------------------------------------

_llm_show_loader() {
    local pid=$1
    local text="${2:-Thinking}"
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    # Check if process is still running
    while kill -0 "$pid" 2>/dev/null; do
        local frame="${frames:$i:1}"
        zle -M "$text $frame"
        zle -R
        ((i++))
        (( i >= ${#frames} )) && i=0
        zselect -t 10
    done
}

_llm_sanitize_suggestion() {
    local input="$1"
    # Remove markdown code blocks, backticks, and trim whitespace
    echo "$input" | sed -E 's/^```[a-z]*//; s/```$//; s/`//g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

# ------------------------------------------------------------------------------
# Core Logic
# ------------------------------------------------------------------------------

_llm_call_provider() {
    local operation="$1"
    local input_text="$2"
    local prompt=""

    # 1. Prepare Prompt
    if [[ "$operation" == "explain" ]]; then
        prompt="$_llm_prompt_explain $input_text"
    else
        prompt="$_llm_prompt_suggest $input_text"
    fi

        # 2. Resolve Tool Command
        local tool_cmd="${ZSH_LLM_BIN_PATH:-$ZSH_LLM_CLI_TOOL}"

        # 3. Check Tool Availability
        if ! command -v "$tool_cmd" &> /dev/null; then
            echo "Error: Tool '$tool_cmd' not found."
            return 1
        fi

        # 4. Determine Model and Construct Command
        local model=""
        local -a cmd_args

        cmd_args=("$tool_cmd")
    case "$ZSH_LLM_CLI_TOOL" in
        copilot)
            model="$ZSH_LLM_COPILOT_MODEL"
            cmd_args+=("--model" "$model" "--prompt" "$prompt")
            ;;
        gemini)
            model="$ZSH_LLM_GEMINI_MODEL"
            cmd_args+=("--model" "$model" "$prompt")
            ;;
        claude)
            model="$ZSH_LLM_CLAUDE_MODEL"
            cmd_args+=("--model" "$model" "--print" "$prompt")
            ;;
        opencode)
            model="$ZSH_LLM_OPENCODE_MODEL"
            cmd_args+=("run" "--model" "$model" "$prompt")
            ;;
        codex)
            model="$ZSH_LLM_CODEX_MODEL"
            cmd_args+=("--model" "$model" "$prompt")
            ;;
        *)
            echo "Error: Unknown tool '$ZSH_LLM_CLI_TOOL'"
            return 1
            ;;
    esac

    # 4. Execute
    if [[ "$ZSH_LLM_CLI_DEBUG" == "true" ]]; then
        echo "[DEBUG] Tool: $ZSH_LLM_CLI_TOOL" >&2
        echo "[DEBUG] Model: $model" >&2
        echo "[DEBUG] Prompt: $prompt" >&2
        echo "[DEBUG] Command: ${cmd_args[*]}" >&2
        "${cmd_args[@]}"
    else
        "${cmd_args[@]}" 2>/dev/null
    fi
}

# ------------------------------------------------------------------------------
# ZLE Widgets (Silent Mode)
# ------------------------------------------------------------------------------

llm_explain() {
    setopt localoptions no_notify no_monitor
    [[ -z "$BUFFER" ]] && zle -M "Buffer is empty." && return

    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)

    (_llm_call_provider "explain" "$BUFFER" > "$tmp_out" 2> "$tmp_err") &
    local job_pid=$!

    _llm_show_loader $job_pid "Explaining..."

    local output=$(<"$tmp_out")
    local error=$(<"$tmp_err")
    rm -f "$tmp_out" "$tmp_err"

    # Clear loader
    zle -M ""

    if [[ -n "$error" ]]; then
        output="${error}"$'\n'"${output}"
    fi

    # Print to stdout so it persists
    zle -I
    print -P "\n$output\n"
}

llm_suggest() {
    setopt localoptions no_notify no_monitor
    [[ -z "$BUFFER" ]] && zle -M "Enter a requirement first." && return

    local tmp_out=$(mktemp)
    local tmp_err=$(mktemp)

    (_llm_call_provider "suggest" "$BUFFER" > "$tmp_out" 2> "$tmp_err") &
    local job_pid=$!

    _llm_show_loader $job_pid "Suggesting..."

    local output=$(<"$tmp_out")
    local error=$(<"$tmp_err")
    rm -f "$tmp_out" "$tmp_err"

    # Clear loader
    zle -M ""

    output=$(_llm_sanitize_suggestion "$output")

    if [[ -n "$output" ]]; then
        BUFFER="$output"
        CURSOR=$#BUFFER
        if [[ -n "$error" ]]; then
            zle -I
            print -P "$error"
        fi
    else
        zle -I
        print -P "Error: No suggestion received."
        [[ -n "$error" ]] && print -P "$error"
    fi
}

# ------------------------------------------------------------------------------
# Registration
# ------------------------------------------------------------------------------

zle -N llm_explain
zle -N llm_suggest

bindkey '^Xe' llm_explain
bindkey '^Xs' llm_suggest
