#!/usr/bin/env bash
# Runs `flutter pub get`, then restores the AGP-9 plugin patches it wipes.
# Use this instead of a bare `flutter pub get` on this project.
#   ./tool/pub-get.sh            # equivalent to: flutter pub get
#   ./tool/pub-get.sh --offline  # extra args are forwarded to flutter pub get
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

flutter pub get "$@"
dart run "$repo_root/tool/patch_android_plugins.dart"
