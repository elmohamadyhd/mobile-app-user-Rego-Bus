#!/bin/bash
# Stop hook — runs dart format + flutter analyze after each Claude turn.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  exit 0
fi

echo "→ dart format"
dart format . --line-length 80 --set-exit-if-changed || {
  echo "⚠ Formatting issues found. Run: dart format ."
}

echo "→ flutter analyze"
flutter analyze --fatal-infos || {
  echo "⚠ Analysis issues found. Run: flutter analyze"
}
