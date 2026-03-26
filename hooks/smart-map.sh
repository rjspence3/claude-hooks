#!/bin/bash
# ---------------------------------------------------------
# "Smart Map" - Context Injection with X-Ray View
# Injects project structure and code definitions
# ---------------------------------------------------------
INPUT=$(cat)

# Only inject on first prompt per session (avoid token bloat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
FLAG_FILE="/tmp/claude-context-injected-${SESSION_ID}"

if [[ -f "$FLAG_FILE" ]]; then
  # Already injected this session, pass through
  exit 0
fi

# Mark as injected
touch "$FLAG_FILE"

# 1. Project Structure (limit depth, exclude noise)
TREE=$(tree -L 2 -I 'node_modules|__pycache__|.git|venv|env|.venv|dist|build' "$CLAUDE_PROJECT_DIR" --noreport 2>/dev/null || ls -R "$CLAUDE_PROJECT_DIR" 2>/dev/null | head -50)

# 2. Git Status
GIT_STATUS=$(cd "$CLAUDE_PROJECT_DIR" && git status --short 2>/dev/null || echo "Not a git repository")

# 3. X-Ray View: Python class/function definitions
XRAY_PY=$(grep -rE "^(class |def |async def )" "$CLAUDE_PROJECT_DIR" \
  --include="*.py" \
  --exclude-dir={venv,env,.venv,.git,__pycache__,node_modules} \
  2>/dev/null | cut -c 1-120 | head -40)

# 4. X-Ray View: TypeScript/JavaScript exports and functions
XRAY_JS=$(grep -rE "^export (function|const|class|interface|type) " "$CLAUDE_PROJECT_DIR" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  --exclude-dir={node_modules,.git,dist,build} \
  2>/dev/null | cut -c 1-120 | head -30)

# Build context string
CONTEXT="[SYSTEM: Project Map]
$TREE

[SYSTEM: Git Status]
$GIT_STATUS"

if [[ -n "$XRAY_PY" ]]; then
  CONTEXT="$CONTEXT

[SYSTEM: Python Definitions]
$XRAY_PY"
fi

if [[ -n "$XRAY_JS" ]]; then
  CONTEXT="$CONTEXT

[SYSTEM: JS/TS Exports]
$XRAY_JS"
fi

# Output JSON with additional context
jq -n --arg ctx "$CONTEXT" '{additionalContext: $ctx}'
