# Agent Workflow Guide

This file tells AI agents (Claude Code, Cursor Composer, Copilot Workspace, etc.)
how to operate in this repository. Rules in `.cursor/rules/` are the detailed spec;
this file is the routing layer.

## Always-on rules

These cursor rules apply to every task in this repo:

| Rule | Trigger |
|------|---------|
| `architecture.mdc` | Always — governs file placement and layer boundaries |
| `dart-style.mdc` | Always — formatting and import style |
| `ai-behavior.mdc` | Always — quality bar and decision heuristics |
| `riverpod-patterns.mdc` | Any state management or provider work |

## Task routing

### Adding a new feature

1. Read `architecture.mdc` first.
2. Scaffold: `lib/features/<name>/{data,domain,presentation}/`
3. Bottom-up: entity → repository interface → impl → provider → screen → route.
4. Run codegen if Freezed or `@riverpod` is used.
5. Add at least one unit test.

### Fixing a bug

1. Reproduce it with a test first.
2. Fix the root cause, not the symptom.
3. Verify `flutter analyze && flutter test` passes.

### Changing the theme / design tokens

Edit only `core/theme/` files. Never hardcode colors or sizes in widgets.

### Adding a new HTTP endpoint

1. Add method to the repository interface in `domain/`.
2. Implement in `data/` using `ref.watch(dioProvider)`.
3. Model the response with a Freezed + `@JsonSerializable` class.
4. Expose via a `FutureProvider` or `AsyncNotifierProvider`.

### Schema / database changes (Drift)

1. Edit the table in `core/database/tables/`.
2. Bump the schema version in `AppDatabase`.
3. Write a migration in `MigrationStrategy.onUpgrade`.
4. Run `dart run build_runner build --delete-conflicting-outputs`.

## MCP preferences

| Task | Preferred MCP |
|------|--------------|
| Look up Riverpod / go_router / Freezed API | `context7` |
| Read/write GitHub PRs, issues, CI | `github` |
| Implement from Figma design | `figma` |

## Do not use

- Raw `Navigator.push` — use `context.go()`.
- Global mutable state outside Riverpod providers.
- Firebase or Auth0 packages (unless you've added them to `pubspec.yaml` deliberately).
- `dart:io` directly in presentation layer — wrap in a service in `data/`.
