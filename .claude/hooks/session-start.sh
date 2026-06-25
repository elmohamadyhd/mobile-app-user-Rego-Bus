#!/bin/bash
# SessionStart hook — Claude Code on the web.
# Ensures the Flutter toolchain + Dart deps are ready so the agent can
# run `flutter analyze` / `flutter test` from the first turn.
# Idempotent and non-interactive.
set -euo pipefail

# Only provision in the remote web environment; local machines have Flutter.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
    echo "Cloning Flutter (stable)…"
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
  fi
  export PATH="$FLUTTER_DIR/bin:$PATH"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
  fi
fi

cd "$PROJECT_DIR"

[ -f .env ] || cp .env.example .env

flutter --version
flutter pub get

# Regenerate Freezed / Riverpod / Drift outputs (no-op until annotated code added)
dart run build_runner build --delete-conflicting-outputs || true

echo "✓ Session ready"
