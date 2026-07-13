# CLAUDE.md — Flutter Skeleton

> AI assistant primer for this project. Loaded automatically by Claude Code every session.
> Keep it concise. Full architectural detail lives in the Cursor rules under `.cursor/rules/`.

## What this project is

**REGO** (Wadeny) — the Arabic-first, RTL multi-modal travel rider app, built on a
**Riverpod + go_router + Freezed + Dio** foundation. Dart package name: `rego`.
Screens follow the "Skyline" design direction (blue gradient hero + amber accent, Tajawal).

The app covers multiple transport modes — bus, private car, and flight now;
train/ship/cruise/hotel possibly later. Each mode is a fully independent
feature slice (own data/domain/presentation, own booking flow end to end) —
see `docs/superpowers/specs/2026-07-08-multi-vehicle-architecture-design.md`
and the "Multi-vehicle transport features" section in
`.cursor/rules/architecture.mdc` before adding or touching a transport feature.

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
./tool/pub-get.sh             # NOT bare `flutter pub get` — see note below (.ps1 on Windows)
dart run build_runner build --delete-conflicting-outputs   # Freezed / Riverpod codegen
flutter run
flutter analyze && flutter test
```

> **Android build note:** this project runs on the Flutter 3.44.2 default
> toolchain (AGP 9.0.1 / Gradle 9.1.0 / Kotlin 2.3.20, `builtInKotlin=false`).
> `url_launcher_android` ships an AGP-9 Built-in-Kotlin build script that fails
> to compile under that flag, so it's patched in the pub cache. A bare
> `flutter pub get` wipes that patch and breaks the Android build. Always use
> `./tool/pub-get.sh` / `tool/pub-get.ps1`, or run
> `dart run tool/patch_android_plugins.dart` after any manual `pub get`. Details:
> [`tool/README.md`](tool/README.md).

## Adding a feature

1. `lib/features/<name>/{data,domain,presentation}/`
2. Entity in `domain/entities/` (use Freezed)
3. Repository interface in `domain/repositories/`
4. Implementation in `data/repositories/`
5. Riverpod provider in `presentation/providers/`
6. Screen in `presentation/<name>_screen.dart`
7. Federate routes in `presentation/<name>_routes.dart`, spread into `core/router/app_router.dart`

For a new **transport mode** (bus/flight/car-style), it's a full standalone
feature slice, not a branch inside an existing one — see the multi-vehicle
spec linked above.

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
