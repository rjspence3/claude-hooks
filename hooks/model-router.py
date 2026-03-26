#!/usr/bin/env python3
"""
Model Router — classify prompts into work phases for model selection.

Zero external dependencies. Fast regex-based classification with
weighted pattern matching and structural boosters.

Phases:
  QUICK  → haiku  (typos, formatting, renames)
  BUILD  → sonnet (implementation, testing, refactoring)
  PLAN   → opus   (architecture, design, strategy)
  REVIEW → opus   (security audits, edge cases, pre-ship)
"""

import re
import sys
import json
import argparse
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Classification:
    phase: str       # "quick", "build", "plan", "review"
    model: str       # recommended model name
    confidence: float  # 0.0 - 1.0
    scores: dict = field(default_factory=dict)


PHASE_MODEL = {
    "quick": "haiku",
    "build": "sonnet",
    "plan": "opus",
    "review": "opus",
}

# ── Pattern definitions with weights ────────────────────────────────

PATTERNS: dict[str, list[tuple[str, float]]] = {
    "plan": [
        (r"\b(?:architect(?:ure)?|system design)\b", 3.0),
        (r"\b(?:design pattern|abstraction|decouple)\b", 2.5),
        (r"\b(?:plan(?:ning)?|strategy|proposal)\b", 2.5),
        (r"\b(?:trade-?off|pros and cons|compare approach(?:es)?)\b", 2.5),
        (r"\b(?:data model|schema design)\b", 2.0),
        (r"\b(?:microservices?|monolith|event[- ]driven|cqrs)\b", 2.5),
        (r"\bmigration strategy\b", 2.5),
        (r"\b(?:think through|reason about)\b", 2.0),
        (r"\bhow should (?:we|i)\b", 2.0),
        (r"\b(?:scope|spec|specification|requirements)\b", 2.0),
        (r"what(?:'?s| is) the best (?:way|approach|pattern|architecture)\b", 2.0),
        (r"\bshould (?:we|i) (?:use|go with|pick|choose)\b", 2.0),
        (r"\bbefore (?:we|i) (?:start|begin|build)\b", 2.5),
        (r"\b(?:outline|sketch|map out|break down)\b", 2.0),
        (r"\b(?:file structure|project structure|folder structure)\b", 2.0),
    ],
    "build": [
        (r"\b(?:implement|build|create|develop|write|code)\b", 1.5),
        (r"\b(?:refactor|restructure|reorganize)\b", 2.0),
        (r"\b(?:tests?|testing|unit test|coverage)\b", 2.0),
        (r"\b(?:feature|functionality|endpoint|route|handler)\b", 1.5),
        (r"\b(?:component|module|service|class)\b", 1.0),
        (r"\b(?:bug|fix|debug|error|issue)\b", 1.5),
        (r"\b(?:auth|login|session|jwt|oauth)\b", 1.5),
        (r"(?:now let'?s|ok (?:build|implement)|next step|let'?s start)", 2.0),
        (r"\b(?:add|update|change|modify|edit)\b", 1.0),
        (r"\b(?:wire up|hook up|plug in)\b", 1.5),
    ],
    "review": [
        (r"\b(?:review|audit|analyze|assess|evaluate)\b", 2.5),
        (r"\bsecurity (?:audit|review|analysis)\b", 3.0),
        (r"\bvulnerabilit(?:y|ies)\b", 3.0),
        (r"\b(?:race condition|deadlock|concurrency)\b", 3.0),
        (r"\bperformance (?:audit|review|optimization)\b", 2.5),
        (r"\b(?:analyze|assess|evaluate|measure) performance\b", 2.5),
        (r"\b(?:complex|subtle) (?:bug|issue|problem)\b", 2.5),
        (r"\b(?:investigate|root cause|diagnose)\b", 2.0),
        (r"\b(?:edge case|corner case|boundary)\b", 2.0),
        (r"does this look (?:right|correct)\b", 2.0),
        (r"anything (?:i'?m|we'?re) missing\b", 2.0),
        (r"what could go wrong\b", 2.5),
        (r"\bfailure mode\b", 2.5),
        (r"\b(?:code smell|anti[- ]pattern|tech debt)\b", 2.0),
        (r"before (?:we|i) (?:ship|deploy|merge|push)\b", 2.5),
    ],
    "quick": [
        (r"\b(?:typo|spelling)\b", 3.0),
        (r"\brename\b", 2.0),
        (r"\b(?:fix|missing) import\b", 2.5),
        (r"\badd (?:comment|docstring)\b", 2.0),
        (r"\b(?:format|lint|prettier|black|ruff)\b", 2.5),
        (r"\bupdate (?:readme|changelog|version)\b", 2.0),
        (r"\b(?:simple|quick|small|minor) (?:fix|change|edit|tweak)\b", 2.5),
        (r"\b(?:delete|remove) (?:unused|dead|old)\b", 2.0),
        (r"\bsyntax (?:error|issue)\b", 2.5),
    ],
}

# Precompile all patterns
_COMPILED: dict[str, list[tuple[re.Pattern, float]]] = {
    phase: [(re.compile(p, re.IGNORECASE), w) for p, w in pairs]
    for phase, pairs in PATTERNS.items()
}


# ── Structural analysis ─────────────────────────────────────────────

def _word_count(text: str) -> int:
    return len(text.split())


def _question_marks(text: str) -> int:
    return text.count("?")


def _file_references(text: str) -> int:
    return len(re.findall(
        r"(?:~?/?[\w.-]+/[\w.-]+(?:/[\w.-]+)*|\.?/[\w.-]+|\b[\w-]+\.\w{1,5})\b",
        text,
    ))


def _has_code_blocks(text: str) -> bool:
    return "```" in text


def _has_stack_trace(text: str) -> bool:
    return bool(re.search(
        r"(?:Traceback|at .+\(.+:\d+\)|File \".+\", line \d+|Error:.*\n\s+at )",
        text,
    ))


# ── Classifier ───────────────────────────────────────────────────────

def classify(prompt: str) -> Classification:
    text = prompt.strip()
    lower = text.lower()
    words = _word_count(text)

    scores = {phase: 0.0 for phase in PHASE_MODEL}

    # Pattern matching
    for phase, compiled in _COMPILED.items():
        for regex, weight in compiled:
            hits = len(regex.findall(lower))
            scores[phase] += hits * weight

    # Structural boosters
    if words <= 8:
        scores["quick"] += 2.0
    elif words <= 15:
        scores["quick"] += 1.0
    elif 16 <= words <= 50:
        scores["build"] += 1.0
    elif words > 80:
        scores["plan"] += 1.0
        scores["review"] += 0.5

    qmarks = _question_marks(text)
    if qmarks >= 2:
        scores["plan"] += 1.0
        scores["review"] += 1.0

    filerefs = _file_references(text)
    if filerefs >= 3:
        scores["plan"] += 1.0
        scores["review"] += 1.0

    if _has_code_blocks(text):
        scores["build"] += 1.0

    if _has_stack_trace(text):
        scores["build"] += 1.5

    # Winner — on ties, prefer higher-capability phase
    _tiebreak = {"review": 3, "plan": 2, "build": 1, "quick": 0}
    winner = max(scores, key=lambda k: (scores[k], _tiebreak[k]))
    total = sum(scores.values())
    confidence = scores[winner] / total if total > 0 else 0.0

    return Classification(
        phase=winner,
        model=PHASE_MODEL[winner],
        confidence=confidence,
        scores=scores,
    )


# ── Nudge generation ─────────────────────────────────────────────────

_LABELS = {
    "quick": "\u26a1 QUICK",   # ⚡
    "build": "\U0001f527 BUILD",  # 🔧
    "plan": "\U0001f9e0 PLAN",   # 🧠
    "review": "\U0001f50d REVIEW", # 🔍
}

_MODEL_DISPLAY = {
    "haiku": "HAIKU",
    "sonnet": "SONNET",
    "opus": "OPUS",
}


def _normalize_model(name: str) -> str:
    lower = name.lower().strip()
    for key in ("haiku", "sonnet", "opus"):
        if key in lower:
            return key
    return lower


def mismatch_nudge(
    classification: Classification,
    current_model: str,
) -> Optional[str]:
    """Return a nudge string when recommended model != current, else None."""
    current = _normalize_model(current_model)
    recommended = classification.model

    if current == recommended:
        return None

    label = _LABELS[classification.phase]
    display = _MODEL_DISPLAY.get(recommended, recommended.upper())

    if recommended == "opus":
        return f"{label} work detected \u2192 consider {display} for better results. Switch: /model {recommended}"
    elif recommended == "haiku":
        return f"{label} work detected \u2192 {display} would save credits. Switch: /model {recommended}"
    else:
        return f"{label} work detected \u2192 {display} would handle this. Switch: /model {recommended}"


# ── CLI ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Classify prompt work phase")
    parser.add_argument("--current-model", default="opus")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--min-confidence", type=float, default=0.0)
    parser.add_argument("prompt", nargs="?")
    args = parser.parse_args()

    prompt = args.prompt or sys.stdin.read().strip()
    if not prompt:
        sys.exit(0)

    result = classify(prompt)
    nudge = mismatch_nudge(result, args.current_model)

    # Suppress low-confidence nudges
    if nudge and result.confidence < args.min_confidence:
        nudge = None

    if args.json:
        print(json.dumps({
            "phase": result.phase,
            "model": result.model,
            "confidence": round(result.confidence, 3),
            "scores": {k: round(v, 2) for k, v in result.scores.items()},
            "nudge": nudge,
        }))
    else:
        if nudge:
            print(nudge)


if __name__ == "__main__":
    main()
