# CLI benchmark results

Generated: 2026-09-27T16:26:28+00:00

## Methodology

- Uses the plugin's current prompt templates for `suggest` and `explain`.
- Runs all prompts sequentially for each provider CLI.
- Measures wall-clock time per prompt and totals by provider.
- Compares provider-native CLIs only: Claude CLI, Codex CLI, Antigravity CLI, and Grok Build CLI.
- Excludes OpenCode on purpose because it is a generic frontend rather than a provider-specific CLI.

Prompt count: 10 (5 suggest + 5 explain)
Provider count: 4
Sequential suite wall-clock total across all providers: 313.466s

## Summary

| CLI | Model | Version | Success | Suggest total (s) | Explain total (s) | Total (s) | Avg / prompt (s) | Notes |
|---|---|---|---|---|---|---|---|---|
| Claude CLI | haiku | 2.1.280 (Claude Code) | 10/10 | 32.875 | 34.161 | 67.036 | 6.704 | ok |
| Codex CLI | gpt-5.6-luna | codex-cli 0.157.1 | 10/10 | 35.530 | 35.483 | 71.013 | 7.101 | ok |
| Antigravity CLI | gemini-3.8-flash-low | 1.2.12 | 10/10 | 32.626 | 42.389 | 75.015 | 7.502 | ok |
| Grok Build CLI | grok-4.7-build-fast | grok 1.0.4 (d846eb93d94d) [stable] | 10/10 | 67.490 | 32.912 | 100.402 | 10.040 | ok |

## Prompt set

- `s1` (suggest): show the 20 largest files under the current directory
- `s2` (suggest): find every .log file larger than 100MB under /var/log
- `s3` (suggest): count how many TODO comments exist in all JavaScript and TypeScript files in this tree
- `s4` (suggest): create a gzipped tarball of the current directory excluding .git and node_modules
- `s5` (suggest): show disk usage for each top-level directory sorted from largest to smallest
- `e1` (explain): find . -type f -print0 | xargs -0 sha256sum | sort -k2
- `e2` (explain): rsync -avz --delete --partial --info=progress2 src/ remote:/backup/
- `e3` (explain): lsof -iTCP -sTCP:LISTEN -n -P
- `e4` (explain): awk -F: '$3 >= 1000 && $7 !~ /nologin/ { print $1 }' /etc/passwd
- `e5` (explain): ssh -N -L 15432:db.internal:5432 bastion.example.com

## Per-case timings

| CLI | Case | Kind | Seconds | Status |
|---|---|---|---|---|
| Claude CLI | s1:largest-files | suggest | 8.349 | ok |
| Claude CLI | s2:large-log-files | suggest | 4.709 | ok |
| Claude CLI | s3:count-todos | suggest | 8.168 | ok |
| Claude CLI | s4:tarball-excluding-deps | suggest | 5.906 | ok |
| Claude CLI | s5:disk-usage-top-level | suggest | 5.743 | ok |
| Claude CLI | e1:find-xargs-sha256sum | explain | 6.046 | ok |
| Claude CLI | e2:rsync-delete-progress | explain | 6.721 | ok |
| Claude CLI | e3:lsof-listening-tcp | explain | 6.613 | ok |
| Claude CLI | e4:awk-passwd-filter | explain | 7.636 | ok |
| Claude CLI | e5:ssh-local-port-forward | explain | 7.145 | ok |
| Codex CLI | s1:largest-files | suggest | 8.092 | ok |
| Codex CLI | s2:large-log-files | suggest | 6.406 | ok |
| Codex CLI | s3:count-todos | suggest | 8.160 | ok |
| Codex CLI | s4:tarball-excluding-deps | suggest | 6.513 | ok |
| Codex CLI | s5:disk-usage-top-level | suggest | 6.359 | ok |
| Codex CLI | e1:find-xargs-sha256sum | explain | 6.865 | ok |
| Codex CLI | e2:rsync-delete-progress | explain | 8.165 | ok |
| Codex CLI | e3:lsof-listening-tcp | explain | 5.386 | ok |
| Codex CLI | e4:awk-passwd-filter | explain | 9.293 | ok |
| Codex CLI | e5:ssh-local-port-forward | explain | 5.774 | ok |
| Antigravity CLI | s1:largest-files | suggest | 8.741 | ok |
| Antigravity CLI | s2:large-log-files | suggest | 6.620 | ok |
| Antigravity CLI | s3:count-todos | suggest | 5.614 | ok |
| Antigravity CLI | s4:tarball-excluding-deps | suggest | 5.111 | ok |
| Antigravity CLI | s5:disk-usage-top-level | suggest | 6.540 | ok |
| Antigravity CLI | e1:find-xargs-sha256sum | explain | 7.601 | ok |
| Antigravity CLI | e2:rsync-delete-progress | explain | 9.546 | ok |
| Antigravity CLI | e3:lsof-listening-tcp | explain | 8.027 | ok |
| Antigravity CLI | e4:awk-passwd-filter | explain | 7.717 | ok |
| Antigravity CLI | e5:ssh-local-port-forward | explain | 9.498 | ok |
| Grok Build CLI | s1:largest-files | suggest | 11.356 | ok |
| Grok Build CLI | s2:large-log-files | suggest | 6.199 | ok |
| Grok Build CLI | s3:count-todos | suggest | 16.970 | ok |
| Grok Build CLI | s4:tarball-excluding-deps | suggest | 15.664 | ok |
| Grok Build CLI | s5:disk-usage-top-level | suggest | 17.301 | ok |
| Grok Build CLI | e1:find-xargs-sha256sum | explain | 7.402 | ok |
| Grok Build CLI | e2:rsync-delete-progress | explain | 6.300 | ok |
| Grok Build CLI | e3:lsof-listening-tcp | explain | 5.970 | ok |
| Grok Build CLI | e4:awk-passwd-filter | explain | 7.340 | ok |
| Grok Build CLI | e5:ssh-local-port-forward | explain | 5.900 | ok |
