# Runs `flutter pub get`, then restores the AGP-9 plugin patches it wipes.
# Use this instead of a bare `flutter pub get` on this project.
#   ./tool/pub-get.ps1            # equivalent to: flutter pub get
#   ./tool/pub-get.ps1 --offline  # extra args are forwarded to flutter pub get
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

flutter pub get @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dart run "$repoRoot/tool/patch_android_plugins.dart"
exit $LASTEXITCODE
