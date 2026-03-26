# Installation

## 1. Clone the repo

```bash
git clone https://github.com/rjspence3/claude-hooks ~/.claude/hooks-source
```

## 2. Copy hooks to your hooks directory

```bash
mkdir -p ~/claude-hooks
cp ~/.claude/hooks-source/hooks/*.sh ~/claude-hooks/
cp ~/.claude/hooks-source/hooks/model-router.py ~/claude-hooks/
chmod +x ~/claude-hooks/*.sh
```

## 3. Wire hooks into `~/.claude/settings.json`

Add a `hooks` section to your `~/.claude/settings.json`. Below is a complete example with all 7 hooks. Pick the ones you want.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/smart-map.sh"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/route-model.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/safety-net.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/auto-commit.sh"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/enforce-style.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/notify-done.sh"
          }
        ]
      },
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/claude-hooks/smart-archive.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook-by-hook configuration

### `smart-map.sh` (UserPromptSubmit)
No configuration needed. Fires once per session on the first prompt.

**Requires:** `jq`, `tree` (optional — falls back to `ls -R` if `tree` is not installed)

### `auto-commit.sh` (PostToolUse)
No configuration needed. Commits after every Edit or Write.

**Requires:** `git` initialized in your project

### `safety-net.sh` (PreToolUse)
No configuration needed. Blocks dangerous commands by default.

**Requires:** `jq`

### `enforce-style.sh` (PostToolUse)
No configuration needed. Uses whatever formatter is installed.

**Requires:** `ruff` or `black` for Python; `prettier` for JS/TS (falls back to `npx prettier` if global `prettier` is not found)

### `notify-done.sh` (Stop)
No configuration needed. macOS only.

**Requires:** macOS (`osascript`)

### `smart-archive.sh` (Stop)
No configuration needed. Archives plan/TODO files when all tasks are checked off.

### `route-model.sh` (UserPromptSubmit)
Optional env var configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `MODEL_ROUTER_MODE` | `recommend` | Set to `quiet` to disable nudges |
| `MODEL_ROUTER_MIN_CONFIDENCE` | `0.4` | Minimum confidence (0.0–1.0) before nudging |
| `MODEL_ROUTER_CURRENT_MODEL` | auto-detected | Override current model detection |

**Requires:** Python 3, `model-router.py` in the same directory as `route-model.sh`

## Verify installation

Restart Claude Code and open a project. On your first prompt you should see project structure injected into context (from `smart-map.sh`).

To test `safety-net.sh`, ask Claude to run `rm -rf /tmp/test` — it should be blocked.
