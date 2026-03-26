#!/bin/bash
# ---------------------------------------------------------
# "Smart Archive" - Archives completed plan/TODO files
# Runs on session Stop
# ---------------------------------------------------------

# Files to check for completion
TARGETS=("plan.md" "PLAN.md" "TODO.md" "todo.md")
ARCHIVE_DIR="$CLAUDE_PROJECT_DIR/.archive"

archived_count=0

for filename in "${TARGETS[@]}"; do
  FILE_PATH="$CLAUDE_PROJECT_DIR/$filename"

  [[ ! -f "$FILE_PATH" ]] && continue
  [[ ! -s "$FILE_PATH" ]] && continue  # Skip empty files

  # Check for incomplete tasks:
  # - [ ] unchecked markdown checkbox
  # - TODO: or FIXME: markers
  if grep -qE "\[ \]|TODO:|FIXME:" "$FILE_PATH" 2>/dev/null; then
    # Has incomplete items, don't archive
    continue
  fi

  # All tasks complete - archive it
  mkdir -p "$ARCHIVE_DIR"
  TIMESTAMP=$(date "+%Y-%m-%d_%H%M%S")
  DEST="$ARCHIVE_DIR/${TIMESTAMP}_${filename}"

  if mv "$FILE_PATH" "$DEST" 2>/dev/null; then
    ((archived_count++))
  fi
done

if [[ $archived_count -gt 0 ]]; then
  echo "Archived $archived_count completed plan file(s) to .archive/" >&2
fi

exit 0
