#!/bin/bash
# ---------------------------------------------------------
# "Safety Net" - Block dangerous commands
# Returns exit 2 to block, exit 0 to allow
# ---------------------------------------------------------
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only check Bash tool
[[ "$TOOL" != "Bash" ]] && exit 0
[[ -z "$CMD" ]] && exit 0

# Normalize command for pattern matching
# Remove extra spaces, convert to lowercase for comparison
CMD_LOWER=$(echo "$CMD" | tr '[:upper:]' '[:lower:]')

# === BLOCK LIST ===

# Recursive force delete (various forms)
if echo "$CMD" | grep -qE "rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r|--recursive\s+--force|--force\s+--recursive)\s"; then
  echo '{"error": "Blocked: Recursive force delete (rm -rf) is not allowed"}' >&2
  exit 2
fi

# Delete root or home
if echo "$CMD" | grep -qE "rm\s.*\s(/|~|\$HOME|/Users|/home)\s*$"; then
  echo '{"error": "Blocked: Cannot delete root or home directory"}' >&2
  exit 2
fi

# Publishing packages
if echo "$CMD_LOWER" | grep -qE "(npm|yarn|pnpm)\s+publish"; then
  echo '{"error": "Blocked: Package publishing requires manual execution"}' >&2
  exit 2
fi

# Force push to main/master
if echo "$CMD" | grep -qE "git\s+push\s+.*(-f|--force).*\s+(main|master)|git\s+push\s+(-f|--force)\s+(origin\s+)?(main|master)"; then
  echo '{"error": "Blocked: Force push to main/master is not allowed"}' >&2
  exit 2
fi

# Drop database
if echo "$CMD_LOWER" | grep -qE "drop\s+(database|table|schema)"; then
  echo '{"error": "Blocked: DROP DATABASE/TABLE/SCHEMA requires manual execution"}' >&2
  exit 2
fi

# Chmod 777
if echo "$CMD" | grep -qE "chmod\s+777"; then
  echo '{"error": "Blocked: chmod 777 is a security risk"}' >&2
  exit 2
fi

# curl piped to shell
if echo "$CMD" | grep -qE "curl\s.*\|\s*(bash|sh|zsh)"; then
  echo '{"error": "Blocked: Piping curl to shell is dangerous"}' >&2
  exit 2
fi

# All checks passed
exit 0
