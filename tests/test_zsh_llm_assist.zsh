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
        codex) export ZSH_LLM_CODEX_MODEL="$TARGET_MODEL" ;;
        cursor) export ZSH_LLM_CURSOR_MODEL="$TARGET_MODEL" ;;
        antigravity) export ZSH_LLM_ANTIGRAVITY_MODEL="$TARGET_MODEL" ;;
        grok-build) export ZSH_LLM_GROK_BUILD_MODEL="$TARGET_MODEL" ;;
        copilot) export ZSH_LLM_COPILOT_MODEL="$TARGET_MODEL" ;;
        opencode) export ZSH_LLM_OPENCODE_MODEL="$TARGET_MODEL" ;;
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
mock_tool_args_file=$(mktemp)
export mock_tool_output=""

function define_mock_tool() {
    local tool_name="$1"
    eval "function $tool_name() {
        mock_tool_called=1
        printf '%s\n' \"\$@\" >| \"$mock_tool_args_file\"
        echo \"\$mock_tool_output\"
    }"
}

if [[ "${REAL_API:-false}" != "true" ]]; then
    case "$ZSH_LLM_CLI_TOOL" in
        cursor) define_mock_tool "cursor-agent" ;;
        antigravity) define_mock_tool "agy" ;;
        grok-build) define_mock_tool "agent" ;;
        *) define_mock_tool "$ZSH_LLM_CLI_TOOL" ;;
    esac
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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        echo "❌ $msg"
        echo "   Expected to find: $needle"
        echo "   In:               $haystack"
        exit 1
    fi
}

assert_provider_flags() {
    local args_joined="$(tr '\n' ' ' < "$mock_tool_args_file")"

    case "$ZSH_LLM_CLI_TOOL" in
        claude)
            assert_contains "$args_joined" "--model ${TARGET_MODEL:-haiku}" "Claude command should set the configured model"
            assert_contains "$args_joined" "--print" "Claude command should use print mode"
            assert_contains "$args_joined" "--dangerously-skip-permissions" "Claude command should bypass permission prompts"
            ;;
        codex)
            assert_contains "$args_joined" "exec -m ${TARGET_MODEL:-gpt-5.4-mini}" "Codex command should use exec with the configured model"
            assert_contains "$args_joined" "--dangerously-bypass-approvals-and-sandbox" "Codex command should bypass approvals and sandbox"
            assert_contains "$args_joined" "--dangerously-bypass-hook-trust" "Codex command should bypass hook trust"
            ;;
        cursor)
            assert_contains "$args_joined" "--print --output-format text --force" "Cursor command should use non-interactive forced print mode"
            if [[ -n "$TARGET_MODEL" ]]; then
                assert_contains "$args_joined" "--model $TARGET_MODEL" "Cursor command should set an explicit model when configured"
            fi
            ;;
        antigravity)
            assert_contains "$args_joined" "--model ${TARGET_MODEL:-gemini-3.8-flash-low}" "Antigravity command should set the configured model"
            assert_contains "$args_joined" "--print --output-format text --dangerously-skip-permissions" "Antigravity command should run headless without permission prompts"
            ;;
        grok-build)
            assert_contains "$args_joined" "-p" "Grok Build command should use single-turn mode"
            assert_contains "$args_joined" "--output-format plain --permission-mode bypassPermissions" "Grok Build command should run headless without permission prompts"
            assert_contains "$args_joined" "--model ${TARGET_MODEL:-grok-4.7-build-fast}" "Grok Build command should set the configured model"
            ;;
    esac
}

# 5. Run Tests

echo "\n>>> Running Suggest Test..."
BUFFER="list files"
if [[ "${REAL_API:-false}" != "true" ]]; then
    export mock_tool_output="ls"
    llm_suggest
    assert_equals "$BUFFER" "ls" "llm_suggest failed to update BUFFER with mock"
    assert_provider_flags
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
