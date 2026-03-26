#!/bin/bash
# ---------------------------------------------------------
# "Auto Commit" - Git checkpoint after file modifications
# Creates micro-commits for undo capability
# ---------------------------------------------------------
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit early if not a file modification tool
[[ ! "$TOOL" =~ ^(Edit|Write)$ ]] && exit 0

# Exit if no file path
[[ -z "$FILE" ]] && exit 0

# Resolve relative paths
[[ "$FILE" != /* ]] && FILE="$CLAUDE_PROJECT_DIR/$FILE"

# Exit if file doesn't exist
[[ ! -f "$FILE" ]] && exit 0

# Change to project directory for git operations
cd "$CLAUDE_PROJECT_DIR" || exit 0

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Get relative path for cleaner commit message
REL_FILE=$(realpath --relative-to="$CLAUDE_PROJECT_DIR" "$FILE" 2>/dev/null || basename "$FILE")

# Stage and commit
git add "$FILE" 2>/dev/null
git commit -m "Claude checkpoint: $REL_FILE" --no-verify 2>/dev/null

exit 0
