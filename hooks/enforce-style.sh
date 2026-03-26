#!/bin/bash
# ---------------------------------------------------------
# "Enforce Style" - Auto-format after edits
# Runs Ruff/Black (Python) or Prettier (JS/TS)
# ---------------------------------------------------------
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Exit early if no file path
[[ -z "$FILE" ]] && exit 0

# Resolve relative paths to absolute using project dir
[[ "$FILE" != /* ]] && FILE="$CLAUDE_PROJECT_DIR/$FILE"

# Exit if file doesn't exist
[[ ! -f "$FILE" ]] && exit 0

format_python() {
  local file="$1"
  # Prefer Ruff (faster), fallback to Black
  if command -v ruff &>/dev/null; then
    ruff format "$file" 2>/dev/null
  elif command -v black &>/dev/null; then
    black --quiet "$file" 2>/dev/null
  fi
}

format_js() {
  local file="$1"
  if command -v prettier &>/dev/null; then
    prettier --write "$file" 2>/dev/null
  elif command -v npx &>/dev/null; then
    npx prettier --write "$file" 2>/dev/null
  fi
}

case "$FILE" in
  *.py)
    format_python "$FILE"
    ;;
  *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.yaml|*.yml)
    format_js "$FILE"
    ;;
esac

exit 0
