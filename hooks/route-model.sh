#!/bin/bash
# ~/claude-hooks/route-model.sh
# UserPromptSubmit hook — nudges model switching when prompt doesn't match.
#
# Reads the user's prompt, classifies it, checks against the current model,
# and injects a one-line nudge via additionalContext when there's a mismatch.
#
# Config (env vars):
#   MODEL_ROUTER_MODE           "recommend" (default) | "quiet"
#   MODEL_ROUTER_MIN_CONFIDENCE  0.0-1.0 (default: 0.4)
#   MODEL_ROUTER_CURRENT_MODEL   Override model detection
#
# Silent on match. Fast — no LLM calls, no network.

set -uo pipefail

ROUTER_SCRIPT="${HOME}/claude-hooks/model-router.py"

# Bail fast if router doesn't exist
[[ -f "$ROUTER_SCRIPT" ]] || exit 0

# Bail if quiet mode
[[ "${MODEL_ROUTER_MODE:-recommend}" == "quiet" ]] && exit 0

# Read hook input from stdin
INPUT=$(timeout 1 cat 2>/dev/null || echo "{}")

# Extract prompt (handle both field names: "prompt" and "user_prompt")
PROMPT=""
if [[ -n "$INPUT" && "$INPUT" != "{}" ]]; then
    PROMPT=$(echo "$INPUT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data.get('prompt', data.get('user_prompt', '')))
" 2>/dev/null) || true
fi

# Nothing to classify
[[ -z "$PROMPT" ]] && exit 0

# Skip slash commands and very short prompts (< 3 chars)
[[ "$PROMPT" =~ ^/ ]] && exit 0
[[ ${#PROMPT} -lt 3 ]] && exit 0

# Detect current model
if [[ -n "${MODEL_ROUTER_CURRENT_MODEL:-}" ]]; then
    CURRENT_MODEL="$MODEL_ROUTER_CURRENT_MODEL"
else
    # Read from settings.json (updated by /model command)
    SETTINGS="${HOME}/.claude/settings.json"
    if [[ -f "$SETTINGS" ]]; then
        CURRENT_MODEL=$(python3 -c "
import json
with open('$SETTINGS') as f:
    print(json.load(f).get('model', 'opus'))
" 2>/dev/null) || CURRENT_MODEL="opus"
    else
        CURRENT_MODEL="opus"
    fi
fi

MIN_CONFIDENCE="${MODEL_ROUTER_MIN_CONFIDENCE:-0.4}"

# Run classifier
RESULT=$(echo "$PROMPT" | python3 "$ROUTER_SCRIPT" \
    --json \
    --current-model "$CURRENT_MODEL" \
    --min-confidence "$MIN_CONFIDENCE" \
    2>/dev/null) || exit 0

# Extract nudge
NUDGE=$(echo "$RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
nudge = data.get('nudge')
if nudge:
    print(nudge)
" 2>/dev/null) || true

# If there's a nudge, inject it as additional context
if [[ -n "$NUDGE" ]]; then
    jq -n --arg nudge "$NUDGE" '{"additionalContext": $nudge}'
fi

exit 0
