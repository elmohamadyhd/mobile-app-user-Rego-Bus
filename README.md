# Flutter Skeleton

A production-ready Flutter starter template. Clone, rename, and build your app.

## Stack

| Layer | Package |
|-------|---------|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) |
| Navigation | [go_router](https://pub.dev/packages/go_router) |
| Immutable models | [freezed](https://pub.dev/packages/freezed) + [json_serializable](https://pub.dev/packages/json_serializable) |
| HTTP | [dio](https://pub.dev/packages/dio) |
| Env secrets | [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) |
| CI/CD | GitHub Actions |
| AI tooling | Claude Code + Cursor |

## Quick start

```bash
# 1. Clone and rename
git clone <this-repo> my_app
cd my_app

# 2. Rename the package (replace every occurrence of `app_skeleton`)
# macOS/Linux:
grep -rl "app_skeleton" . --include="*.dart" --include="*.yaml" | xargs sed -i 's/app_skeleton/my_app/g'

# 3. Set up secrets
cp .env.example .env
# Edit .env with your API keys

# 4. Install deps + run codegen
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 5. Run
flutter run
```

## Project structure

```
lib/
├── core/
│   ├── config/       # AppConfig — typed env var access
│   ├── network/      # Dio client with auth + logging interceptors
│   ├── router/       # go_router setup + route constants
│   ├── theme/        # AppColors, AppSpacing, AppTypography, AppTheme
│   └── utils/        # AsyncValue extensions and helpers
├── features/
│   └── home/         # Example feature (data / domain / presentation)
└── shared/
    └── widgets/      # AppScaffold and other reusable widgets
```

## Adding a feature

```
lib/features/<name>/
├── data/
│   └── repositories/<name>_repository_impl.dart
├── domain/
│   ├── entities/<name>.dart           # Freezed model
│   └── repositories/<name>_repository.dart  # Abstract interface
└── presentation/
    ├── providers/<name>_providers.dart
    └── <name>_screen.dart
```

Then register a route in `core/router/app_router.dart`.

## AI tooling

This skeleton ships with first-class AI assistant support:

### Claude Code (claude.ai/code)
- `CLAUDE.md` — project primer loaded every session
- `.claude/settings.json` — MCP servers + permission allowlists
- `.claude/hooks/session-start.sh` — auto-installs Flutter in cloud sessions
- `.claude/hooks/format-analyze.sh` — runs format + analyze after each turn

### Cursor
- `.cursor/rules/architecture.mdc` — feature-first layer rules
- `.cursor/rules/riverpod-patterns.mdc` — provider patterns
- `.cursor/rules/dart-style.mdc` — formatting and code quality
- `.cursor/rules/ai-behavior.mdc` — quality bar for AI-generated code
- `.cursor/AGENTS.md` — task routing for Cursor Composer

### MCP servers configured

| Server | Purpose |
|--------|---------|
| `github` | PR/issue management, CI status |
| `context7` | Live Dart/Flutter package documentation |
| `figma` | Design-to-code, component reference |

Set `GITHUB_TOKEN` and `FIGMA_API_KEY` in your environment to activate them.

## Code generation

After editing any `@freezed`, `@riverpod`, or `@JsonSerializable` class:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated files (`*.g.dart`, `*.freezed.dart`) are gitignored.

## CI

GitHub Actions runs on every push:
1. `dart format` check
2. `flutter analyze --fatal-infos`
3. `flutter test --coverage`
4. Android APK build (on `main` only)

## Checklist when starting a real project

- [ ] Rename `app_skeleton` → your package name everywhere
- [ ] Update `pubspec.yaml` `name`, `description`, `version`
- [ ] Set brand colors in `core/theme/app_colors.dart`
- [ ] Choose typography in `core/theme/app_typography.dart`
- [ ] Fill `.env` with real API keys
- [ ] Update `android/app/build.gradle` with your `applicationId`
- [ ] Replace `HomeScreen` with your first real screen
- [ ] Add your own routes to `core/router/app_router.dart`
- [ ] Update this README
