# Benchmark suite

This folder contains a reproducible latency benchmark for the provider-native CLIs supported by `zsh-llm-assist`:

- Claude CLI (`claude`)
- Codex CLI (`codex`)
- Antigravity CLI (`agy`)
- Grok Build CLI (`agent`)

It intentionally does **not** benchmark OpenCode, because OpenCode is a generic frontend that can target many different models, so it is not a meaningful provider-to-provider comparison.

## Prompt set

The benchmark prompt corpus lives in [`prompts.json`](./prompts.json):

- 5 natural-language requests for `suggest`
- 5 somewhat-esoteric shell commands for `explain`

The runner wraps each prompt with the same prompt templates used by `zsh-llm-assist.plugin.zsh` so the benchmark stays close to real plugin usage.

## Run it

```bash
python3 benchmark/run.py --update-readme
```

By default the suite runs sequentially, in this order:

1. Claude CLI
2. Codex CLI
3. Antigravity CLI
4. Grok Build CLI

Each provider receives all 10 prompts, one after another, and the script records:

- per-prompt wall-clock time
- suggest subtotal
- explain subtotal
- total sequential time per provider
- the combined suite wall-clock total

## Model defaults used by the benchmark

These defaults are intentionally biased toward the fastest tiers for each provider and can be overridden with environment variables.

- `ZSH_LLM_BENCH_CLAUDE_MODEL=haiku`
- `ZSH_LLM_BENCH_CODEX_MODEL=gpt-5.6-luna`
- `ZSH_LLM_BENCH_ANTIGRAVITY_MODEL=gemini-3.8-flash-low`
- `ZSH_LLM_BENCH_GROK_BUILD_MODEL=grok-4.7-build-fast`

## Notes

- Claude CLI is run with `ANTHROPIC_API_KEY` / `CLAUDE_API_KEY` unset inside the benchmark subprocess so local Claude Code login can be used even if an API key is present in the shell environment.
- Results are written to `benchmark/results/latest.json` and `benchmark/results/latest.md`.
- Passing `--update-readme` refreshes the benchmark table embedded in the top-level `README.md`.
