# CLAUDE.md — Flutter Skeleton

> AI assistant primer for this project. Loaded automatically by Claude Code every session.
> Keep it concise. Full architectural detail lives in the Cursor rules under `.cursor/rules/`.

## What this project is

**REGO Buses** (Wadeny) — the Arabic-first, RTL rider mobile app, built on a
**Riverpod + go_router + Freezed + Dio** foundation. Dart package name: `rego`.
Screens follow the "Skyline" design direction (blue gradient hero + amber accent, Tajawal).

## Architecture at a glance

```
lib/
├── core/       # Theme, router, config, network, utils — no feature dependencies
├── features/   # Feature-first slices: data / domain / presentation
└── shared/     # Widgets and models shared across 2+ features
```

Full rules → `.cursor/rules/architecture.mdc`

## Build & run

```bash
cp .env.example .env          # once — fill in your secrets
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Freezed / Riverpod codegen
flutter run
flutter analyze && flutter test
```

## Adding a feature

1. `lib/features/<name>/{data,domain,presentation}/`
2. Entity in `domain/entities/` (use Freezed)
3. Repository interface in `domain/repositories/`
4. Implementation in `data/repositories/`
5. Riverpod provider in `presentation/providers/`
6. Screen in `presentation/<name>_screen.dart`
7. Route in `core/router/app_router.dart`

## Key packages and why

| Package | Role |
|---------|------|
| `flutter_riverpod` | State management — all state lives in providers |
| `go_router` | Declarative navigation; use `context.go()` |
| `freezed` | Immutable data classes + union types |
| `json_serializable` | JSON ↔ Dart; always via `factory.fromJson` |
| `dio` | HTTP; pre-configured client in `core/network/dio_client.dart` |
| `flutter_dotenv` | Secrets from `.env`; accessed via `AppConfig` |

## Codegen

Any file annotated with `@freezed`, `@riverpod`, or `@JsonSerializable` requires:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Generated `*.g.dart` / `*.freezed.dart` are gitignored — never edit them manually.

## AI behavior rules

See `.cursor/rules/ai-behavior.mdc` — the rules there apply to Cursor, Claude Code, and any
other AI assistant working in this repo.

## Cursor rules loaded automatically

| Rule file | Scope |
|-----------|-------|
| `architecture.mdc` | Feature structure, naming, layer rules |
| `riverpod-patterns.mdc` | Provider types, patterns, anti-patterns |
| `dart-style.mdc` | Formatting, imports, const, nullability |
| `ai-behavior.mdc` | AI quality bar and decision heuristics |

## MCP tools configured

| MCP | When to use |
|-----|-------------|
| `github` | PRs, issues, CI status |
| `context7` | Live docs for Riverpod, go_router, Freezed, Dio |
| `figma` | Design-to-code, component reference |

## Recommended skills to invoke

| Skill | When |
|-------|------|
| `/code-review` | Before committing new features |
| `/security-review` | Before any auth or API secrets work |
| `/run` | To launch the app and verify a feature visually |
| `/verify` | After a fix — confirm it actually works |

## Environment notes

- Dev machine: your local environment (`flutter run` works directly).
- Claude Code on the web: `.claude/hooks/session-start.sh` installs Flutter automatically.
- Secrets: always read from `.env` via `AppConfig`; never hardcode.
