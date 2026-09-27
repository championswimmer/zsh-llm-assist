#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
BENCH_DIR = Path(__file__).resolve().parent
PROMPTS_PATH = BENCH_DIR / "prompts.json"
RESULTS_DIR = BENCH_DIR / "results"
README_PATH = ROOT / "README.md"

EXPLAIN_PROMPT_PREFIX = (
    "You are a Zsh expert helper. Explain what a specific shell command does using only general shell knowledge. "
    "Rules: 0. No tool usage or extra thinking. 1. Keep the explanation between 2 to 4 sentences. "
    "2. Be clear and plain-spoken. 3. Do not repeat the command, just explain its effect. "
    "4. Do not use Markdown formatting. Command to explain:"
)

SUGGEST_PROMPT_PREFIX = (
    "You are a Zsh command generator. Return ONLY the raw command string required to fulfill the user request using only general shell knowledge. "
    "Rules: 0. No tool usage or extra thinking. 1. Output MUST be a valid executable Zsh command. 2. NO markdown formatting (no backticks). "
    "3. NO explanatory text. 4. NO leading/trailing whitespace. 5. If multiple steps are needed, chain them with && or ;. Request:"
)


@dataclass(frozen=True)
class Provider:
    key: str
    label: str
    binary: str
    model: str
    version_cmd: list[str]
    build_command: Callable[[str, str], list[str]]
    env_overrides: dict[str, str | None] | None = None


def _env_model(name: str, default: str) -> str:
    return os.environ.get(name, default)


PROVIDERS: dict[str, Provider] = {
    "claude": Provider(
        key="claude",
        label="Claude CLI",
        binary="claude",
        model=_env_model("ZSH_LLM_BENCH_CLAUDE_MODEL", "haiku"),
        version_cmd=["claude", "--version"],
        build_command=lambda prompt, model: [
            "claude",
            "--model",
            model,
            "--print",
            "--output-format",
            "text",
            "--dangerously-skip-permissions",
            prompt,
        ],
        env_overrides={"ANTHROPIC_API_KEY": None, "CLAUDE_API_KEY": None},
    ),
    "codex": Provider(
        key="codex",
        label="Codex CLI",
        binary="codex",
        model=_env_model("ZSH_LLM_BENCH_CODEX_MODEL", "gpt-5.6-luna"),
        version_cmd=["codex", "--version"],
        build_command=lambda prompt, model: [
            "codex",
            "exec",
            "-m",
            model,
            "--dangerously-bypass-approvals-and-sandbox",
            "--dangerously-bypass-hook-trust",
            prompt,
        ],
    ),
    "antigravity": Provider(
        key="antigravity",
        label="Antigravity CLI",
        binary="agy",
        model=_env_model("ZSH_LLM_BENCH_ANTIGRAVITY_MODEL", "gemini-3.8-flash-low"),
        version_cmd=["agy", "--version"],
        build_command=lambda prompt, model: [
            "agy",
            "--model",
            model,
            "--output-format",
            "text",
            "--dangerously-skip-permissions",
            f"--print={prompt}",
        ],
    ),
    "grok-build": Provider(
        key="grok-build",
        label="Grok Build CLI",
        binary="agent",
        model=_env_model("ZSH_LLM_BENCH_GROK_BUILD_MODEL", "grok-4.7-build-fast"),
        version_cmd=["agent", "--version"],
        build_command=lambda prompt, model: [
            "agent",
            "-p",
            prompt,
            "--output-format",
            "plain",
            "--permission-mode",
            "bypassPermissions",
            "--model",
            model,
        ],
    ),
}


def load_cases() -> list[dict]:
    data = json.loads(PROMPTS_PATH.read_text())
    cases: list[dict] = []
    for kind in ("suggest", "explain"):
        for entry in data[kind]:
            if kind == "suggest":
                prompt = f"{SUGGEST_PROMPT_PREFIX} {entry['input']}"
            else:
                prompt = f"{EXPLAIN_PROMPT_PREFIX} {entry['input']}"
            cases.append(
                {
                    "id": entry["id"],
                    "kind": kind,
                    "title": entry["title"],
                    "input": entry["input"],
                    "prompt": prompt,
                }
            )
    return cases


def provider_env(provider: Provider) -> dict[str, str]:
    env = os.environ.copy()
    for key, value in (provider.env_overrides or {}).items():
        if value is None:
            env.pop(key, None)
        else:
            env[key] = value
    return env


def command_exists(binary: str) -> bool:
    return subprocess.run(["bash", "-lc", f"command -v {binary}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def get_version(provider: Provider) -> str:
    try:
        cp = subprocess.run(
            provider.version_cmd,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=20,
            cwd=ROOT,
            env=provider_env(provider),
        )
    except Exception as exc:  # pragma: no cover - defensive only
        return f"error: {exc}"
    text = (cp.stdout or cp.stderr or "").strip().splitlines()
    return text[0] if text else "unknown"


def run_case(provider: Provider, case: dict, timeout_s: int) -> dict:
    cmd = provider.build_command(case["prompt"], provider.model)
    env = provider_env(provider)
    started = time.perf_counter()
    try:
        cp = subprocess.run(
            cmd,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            cwd=ROOT,
            env=env,
        )
        elapsed = time.perf_counter() - started
        return {
            "case_id": case["id"],
            "kind": case["kind"],
            "title": case["title"],
            "input": case["input"],
            "elapsed_s": round(elapsed, 3),
            "ok": cp.returncode == 0,
            "exit_code": cp.returncode,
            "stdout": (cp.stdout or "").strip(),
            "stderr": (cp.stderr or "").strip(),
            "command": cmd,
        }
    except subprocess.TimeoutExpired as exc:
        elapsed = time.perf_counter() - started
        return {
            "case_id": case["id"],
            "kind": case["kind"],
            "title": case["title"],
            "input": case["input"],
            "elapsed_s": round(elapsed, 3),
            "ok": False,
            "exit_code": None,
            "stdout": ((exc.stdout or b"").decode() if isinstance(exc.stdout, bytes) else (exc.stdout or "")).strip(),
            "stderr": ((exc.stderr or b"").decode() if isinstance(exc.stderr, bytes) else (exc.stderr or "")).strip(),
            "command": cmd,
            "timed_out": True,
        }


def summarise_provider(provider: Provider, version: str, results: list[dict]) -> dict:
    total = round(sum(item["elapsed_s"] for item in results), 3)
    suggest_total = round(sum(item["elapsed_s"] for item in results if item["kind"] == "suggest"), 3)
    explain_total = round(sum(item["elapsed_s"] for item in results if item["kind"] == "explain"), 3)
    success_count = sum(1 for item in results if item["ok"])
    avg = round(total / len(results), 3) if results else 0.0
    failed = [item for item in results if not item["ok"]]
    note = "ok"
    if failed:
        first = failed[0]
        err = first["stderr"].splitlines()[-1] if first["stderr"] else "unknown error"
        note = err[:120]
    return {
        "provider": provider.key,
        "label": provider.label,
        "binary": provider.binary,
        "version": version,
        "model": provider.model,
        "success_count": success_count,
        "total_count": len(results),
        "suggest_total_s": suggest_total,
        "explain_total_s": explain_total,
        "total_s": total,
        "avg_s": avg,
        "note": note,
        "cases": results,
    }


def make_summary_table(summary_rows: list[dict]) -> str:
    headers = [
        "CLI",
        "Model",
        "Version",
        "Success",
        "Suggest total (s)",
        "Explain total (s)",
        "Total (s)",
        "Avg / prompt (s)",
        "Notes",
    ]
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for row in sorted(summary_rows, key=lambda item: (item["success_count"] != item["total_count"], item["total_s"])):
        version = row["version"].replace("|", "\\|")
        note = row["note"].replace("|", "\\|")
        lines.append(
            "| "
            + " | ".join(
                [
                    row["label"],
                    row["model"],
                    version,
                    f"{row['success_count']}/{row['total_count']}",
                    f"{row['suggest_total_s']:.3f}",
                    f"{row['explain_total_s']:.3f}",
                    f"{row['total_s']:.3f}",
                    f"{row['avg_s']:.3f}",
                    note,
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def make_case_table(summary_rows: list[dict]) -> str:
    headers = ["CLI", "Case", "Kind", "Seconds", "Status"]
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for row in summary_rows:
        for case in row["cases"]:
            status = "ok" if case["ok"] else f"fail ({case.get('exit_code', 'timeout')})"
            lines.append(
                f"| {row['label']} | {case['case_id']}:{case['title']} | {case['kind']} | {case['elapsed_s']:.3f} | {status} |"
            )
    return "\n".join(lines)


def build_markdown(result: dict) -> str:
    overall_total = round(sum(row["total_s"] for row in result["providers"]), 3)
    prompt_count = len(result["cases"])
    provider_count = len(result["providers"])
    lines = [
        "# CLI benchmark results",
        "",
        f"Generated: {result['generated_at']}",
        "",
        "## Methodology",
        "",
        "- Uses the plugin's current prompt templates for `suggest` and `explain`.",
        "- Runs all prompts sequentially for each provider CLI.",
        "- Measures wall-clock time per prompt and totals by provider.",
        "- Compares provider-native CLIs only: Claude CLI, Codex CLI, Antigravity CLI, and Grok Build CLI.",
        "- Excludes OpenCode on purpose because it is a generic frontend rather than a provider-specific CLI.",
        "",
        f"Prompt count: {prompt_count} ({sum(1 for case in result['cases'] if case['kind'] == 'suggest')} suggest + {sum(1 for case in result['cases'] if case['kind'] == 'explain')} explain)",
        f"Provider count: {provider_count}",
        f"Sequential suite wall-clock total across all providers: {overall_total:.3f}s",
        "",
        "## Summary",
        "",
        make_summary_table(result["providers"]),
        "",
        "## Prompt set",
        "",
    ]
    for case in result["cases"]:
        lines.append(f"- `{case['id']}` ({case['kind']}): {case['input']}")
    lines.extend([
        "",
        "## Per-case timings",
        "",
        make_case_table(result["providers"]),
        "",
    ])
    return "\n".join(lines)


def build_readme_snippet(result: dict) -> str:
    overall_total = round(sum(row["total_s"] for row in result["providers"]), 3)
    return "\n".join(
        [
            f"_Last benchmark run: {result['generated_at']}_",
            "",
            make_summary_table(result["providers"]),
            "",
            f"Sequential suite wall-clock total across all compared CLIs: {overall_total:.3f}s.",
            "",
            "Prompt corpus: 5 suggest requests + 5 explain requests from `benchmark/prompts.json`, using the same prompt wrappers as the plugin.",
        ]
    )


def update_readme(snippet: str) -> None:
    start_marker = "<!-- benchmark-table:start -->"
    end_marker = "<!-- benchmark-table:end -->"
    readme = README_PATH.read_text()
    block = f"{start_marker}\n{snippet}\n{end_marker}"

    if start_marker in readme and end_marker in readme:
        before, remainder = readme.split(start_marker, 1)
        _, after = remainder.split(end_marker, 1)
        updated = before + block + after
    else:
        section = (
            "## Benchmark\n\n"
            "Reproducible CLI latency benchmarks live in [`benchmark/`](benchmark). This suite intentionally excludes OpenCode because it can front any model and would not be a provider-specific comparison.\n\n"
            "### Latest local run\n\n"
            f"{block}\n\n"
        )
        if "## License" in readme:
            updated = readme.replace("## License", section + "## License", 1)
        else:
            updated = readme.rstrip() + "\n\n" + section
    README_PATH.write_text(updated)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark supported provider CLIs for zsh-llm-assist")
    parser.add_argument(
        "--providers",
        nargs="+",
        choices=list(PROVIDERS.keys()),
        default=list(PROVIDERS.keys()),
        help="Providers to benchmark in order",
    )
    parser.add_argument("--timeout", type=int, default=180, help="Per-prompt timeout in seconds")
    parser.add_argument("--update-readme", action="store_true", help="Update README.md with the latest summary table")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    cases = load_cases()
    run_result = {
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "cases": [{key: case[key] for key in ("id", "kind", "title", "input")} for case in cases],
        "providers": [],
    }

    for provider_key in args.providers:
        provider = PROVIDERS[provider_key]
        print(f"== {provider.label} ({provider.model}) ==", flush=True)
        if not command_exists(provider.binary):
            summary = {
                "provider": provider.key,
                "label": provider.label,
                "binary": provider.binary,
                "version": "missing",
                "model": provider.model,
                "success_count": 0,
                "total_count": len(cases),
                "suggest_total_s": 0.0,
                "explain_total_s": 0.0,
                "total_s": 0.0,
                "avg_s": 0.0,
                "note": f"binary '{provider.binary}' not found",
                "cases": [],
            }
            run_result["providers"].append(summary)
            print(summary["note"], flush=True)
            continue

        version = get_version(provider)
        case_results = []
        for index, case in enumerate(cases, start=1):
            print(f"  [{index:02d}/{len(cases)}] {case['kind']}:{case['title']}", flush=True)
            result = run_case(provider, case, args.timeout)
            case_results.append(result)
            state = "ok" if result["ok"] else "fail"
            print(f"      {state} in {result['elapsed_s']:.3f}s", flush=True)
        run_result["providers"].append(summarise_provider(provider, version, case_results))

    json_path = RESULTS_DIR / "latest.json"
    md_path = RESULTS_DIR / "latest.md"
    json_path.write_text(json.dumps(run_result, indent=2) + "\n")
    md_path.write_text(build_markdown(run_result))

    snippet = build_readme_snippet(run_result)
    if args.update_readme:
        update_readme(snippet)

    print()
    print(make_summary_table(run_result["providers"]))
    print()
    print(f"Wrote {json_path.relative_to(ROOT)} and {md_path.relative_to(ROOT)}")
    if args.update_readme:
        print(f"Updated {README_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
