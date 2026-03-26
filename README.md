# claude-hooks — Claude Code Hook System

**7 hooks for Claude Code, built from 6 months of daily use. Covers safety, context injection, auto-formatting, model routing, and session lifecycle.**

---

## Hooks

| Hook | Trigger | What it does | Requires |
|------|---------|--------------|----------|
| `smart-map.sh` | Session start (`UserPromptSubmit`, first prompt) | Injects project file tree + code definitions into context | `jq` |
| `auto-commit.sh` | After Edit/Write (`PostToolUse`) | Creates micro-commits after file edits — instant undo checkpoints | `git` |
| `safety-net.sh` | Before Bash (`PreToolUse`) | Blocks destructive commands: `rm -rf`, `DROP TABLE`, force-push, etc. | `jq` |
| `enforce-style.sh` | After Edit/Write (`PostToolUse`) | Auto-formats Python (Ruff/Black) and JS/TS (Prettier) on save | `ruff` or `black`, `prettier` |
| `notify-done.sh` | Session stop (`Stop`) | macOS notification when Claude Code task completes | macOS only |
| `smart-archive.sh` | Session stop (`Stop`) | Archives completed `PLAN.md` / `TODO.md` to `.archive/` | none |
| `route-model.sh` | Every prompt (`UserPromptSubmit`) | Classifies prompt type and nudges model switching when there's a mismatch | Python 3, `model-router.py` |

---

## Hook details

### `smart-map.sh`
Fires once per session on the first prompt. Generates a project tree (2 levels deep, ignoring `node_modules`, `__pycache__`, `.git`), git status, and an "X-Ray" view of Python class/function definitions and TypeScript/JavaScript exports. Injects everything as `additionalContext` so Claude has immediate project awareness without you having to explain the layout.

### `auto-commit.sh`
After every `Edit` or `Write` tool call, stages the modified file and creates a `Claude checkpoint: <file>` commit. Gives you a complete undo history of every change Claude made — roll back with `git log` + `git checkout`. Uses `--no-verify` to skip pre-commit hooks.

### `safety-net.sh`
Intercepts `Bash` tool calls and blocks a curated list of dangerous patterns before execution:
- `rm -rf` (recursive force delete)
- Deletion of root or home directories
- `npm publish` / `yarn publish` / `pnpm publish`
- Force-push to `main` or `master`
- `DROP DATABASE` / `DROP TABLE` / `DROP SCHEMA`
- `chmod 777`
- `curl ... | bash` (remote script execution)

Returns exit code `2` to block the tool call and surfaces an error message to Claude.

### `enforce-style.sh`
After every `Edit` or `Write` call, detects the file extension and runs the appropriate formatter:
- `.py` → Ruff (preferred) or Black (fallback)
- `.js`, `.jsx`, `.ts`, `.tsx`, `.json`, `.css`, `.scss`, `.md`, `.yaml`, `.yml` → Prettier

Silent if the formatter isn't installed.

### `notify-done.sh`
Uses `osascript` to fire a macOS notification with sound when Claude Code's session ends. Useful when running long tasks in the background.

### `smart-archive.sh`
On session stop, checks for `PLAN.md`, `plan.md`, `TODO.md`, and `todo.md` in the project root. If all tasks are checked off (no `[ ]`, `TODO:`, or `FIXME:` markers remain), moves the file to `.archive/<timestamp>_<filename>`. Keeps your project root clean without losing the history.

### `route-model.sh`
Classifies every prompt using `model-router.py` (keyword heuristics, no LLM calls) and compares the result against the currently active model. If there's a mismatch above the confidence threshold (default: 0.4), injects a one-line nudge like `> Model suggestion: this looks like a planning task — consider switching to Opus`. Configure with env vars:
- `MODEL_ROUTER_MODE=quiet` — disables nudges entirely
- `MODEL_ROUTER_MIN_CONFIDENCE=0.6` — raise the bar before nudging
- `MODEL_ROUTER_CURRENT_MODEL=sonnet` — override model detection

---

## Installation

See [INSTALL.md](INSTALL.md) for full setup instructions.

---

## What's not included

Three hooks from the original system are excluded because they depend on Kernel-specific infrastructure:
- `dangerous-action-gate.sh` — integrates with Kernel's approval queue
- `action-approval-handler.sh` — Kernel webhook receiver
- `auto-logger.sh` — writes to Kernel's structured log system

---

## License

MIT
