#!/usr/bin/env zsh

# ------------------------------------------------------------------------------
# Test Harness for zsh-llm-assist
# ------------------------------------------------------------------------------

# 1. Environment Setup
export ZSH_LLM_CLI_TOOL="${TOOL:-claude}"
TARGET_MODEL="${MODEL:-}"

# For testing with actual CLI tool instead of mocked response
#export REAL_API=true

# Map generic MODEL arg to plugin-specific variables
if [[ -n "$TARGET_MODEL" ]]; then
    case "$ZSH_LLM_CLI_TOOL" in
        gemini) export ZSH_LLM_GEMINI_MODEL="$TARGET_MODEL" ;;
        claude) export ZSH_LLM_CLAUDE_MODEL="$TARGET_MODEL" ;;
        codex)  export ZSH_LLM_CODEX_MODEL="$TARGET_MODEL" ;;
        copilot) export ZSH_LLM_COPILOT_MODEL="$TARGET_MODEL" ;;
    esac
fi

echo "Running tests with:"
echo "  TOOL:     $ZSH_LLM_CLI_TOOL"
echo "  MODEL:    ${TARGET_MODEL:-(default)}"
echo "  REAL_API: ${REAL_API:-false}"

# 2. Mocks

# Mock ZLE (Zsh Line Editor)
BUFFER=""
CURSOR=0

zle() {
    local cmd="$1"
    shift
    case "$cmd" in
        -M) ;; # Message (status line)
        -I) ;; # Invalidate (prepare to print)
        -R) ;; # Redisplay
        -N) ;; # Register widget
        *)  ;;
    esac
}

# Mock zselect (avoid delay)
zselect() { return 0; }

# Mock the CLI Tool to capture output and verify arguments
mock_tool_called=0
export mock_tool_output=""

function define_mock_tool() {
    local tool_name="$1"
    # Use single quotes for the inner function body to prevent early expansion of $mock_tool_output
    eval "function $tool_name() {
        echo \"\$mock_tool_output\"
    }"
}

if [[ "${REAL_API:-false}" != "true" ]]; then
    define_mock_tool "$ZSH_LLM_CLI_TOOL"
fi

# 3. Load Plugin
PLUGIN_FILE="./zsh-llm-assist.plugin.zsh"
[[ ! -f "$PLUGIN_FILE" ]] && PLUGIN_FILE="../zsh-llm-assist.plugin.zsh"
[[ ! -f "$PLUGIN_FILE" ]] && echo "Error: Plugin not found" && exit 1

# Prevent zmodload error
zmodload() { return 0; }

source "$PLUGIN_FILE"

# Capture print -P output
output_captured=""
print() {
    if [[ "$1" == "-P" ]]; then shift; fi
    output_captured="$*"
    builtin print -r -- "$*" # Also print to real stdout
}

# 4. Helper for assertions
assert_not_empty() {
    local val="$1"
    local msg="$2"
    if [[ -z "$val" ]]; then
        echo "❌ $msg (Expected non-empty, got empty)"
        exit 1
    fi
}

assert_equals() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "❌ $msg"
        echo "   Expected: $expected"
        echo "   Got:      $actual"
        exit 1
    fi
}

# 5. Run Tests

echo "\n>>> Running Suggest Test..."
BUFFER="list files"
if [[ "${REAL_API:-false}" != "true" ]]; then
    export mock_tool_output="ls"
    llm_suggest
    assert_equals "$BUFFER" "ls" "llm_suggest failed to update BUFFER with mock"
else
    llm_suggest
    assert_not_empty "$BUFFER" "llm_suggest returned empty BUFFER with real API"
fi
echo "✅ Suggest Test Passed"

echo "\n>>> Running Explain Test..."
BUFFER="ls -la"
output_captured=""
if [[ "${REAL_API:-false}" != "true" ]]; then
    export mock_tool_output="Lists all files including hidden ones"
    llm_explain
    if [[ "$output_captured" == *"$mock_tool_output"* ]]; then
        echo "✅ Explain Test Passed"
    else
        assert_equals "$output_captured" "$mock_tool_output" "llm_explain failed to print mock output"
    fi
else
    llm_explain
    assert_not_empty "$output_captured" "llm_explain returned empty output with real API"
    echo "✅ Explain Test Passed"
fi

echo "\n🎉 All tests passed successfully!"
