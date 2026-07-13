# `tool/` — build maintenance scripts

## AGP-9 plugin patcher

REGO's Android build runs on the **Flutter 3.44.2 default toolchain**: AGP 9.0.1
+ Gradle 9.1.0 + Kotlin 2.3.20, with `android.builtInKotlin=false` in
[`../android/gradle.properties`](../android/gradle.properties) (a flag added by
the Flutter template).

Some plugins ship an `android/build.gradle.kts` written for AGP 9's **Built-in
Kotlin**: they use the `kotlin { compilerOptions { … } }` accessor while only
applying `com.android.library`, relying on AGP to supply Kotlin. With
`builtInKotlin=false` that accessor doesn't exist, so the plugin's build script
**fails to compile**:

```
e: …/url_launcher_android-6.3.32/android/build.gradle.kts:35:1:
   None of the following candidates is applicable: … kotlin(…)
```

The fix is to make the plugin apply the Kotlin Gradle Plugin **explicitly** (the
same way `jni`/`jni_flutter` already do — which is why those build fine under
`builtInKotlin=false`). Flipping the flag to `true` instead would fix this
plugin but risk breaking the explicit-KGP plugins, which is why Flutter ships it
as `false`.

### The problem this solves

The patched files live in the **global pub cache**, outside this repo. They are
silently wiped by:

- `flutter pub get` (when it re-fetches a package),
- `dart pub cache repair`,
- a version bump of a patched plugin.

When that happens the build breaks again with the error above.

### The fix

`plugin_patches/` holds known-good patched copies, one per `<name>-<version>`.
[`patch_android_plugins.dart`](patch_android_plugins.dart) restores them into
the pub cache. It locates each plugin via `.dart_tool/package_config.json`, so it
only ever touches plugins **this project actually depends on**, and it refuses to
patch a version it has no snapshot for (loud warning instead of a silent
mis-patch).

Currently patched: **`url_launcher_android`** (the only affected dependency of
this project).

### Usage

Run the wrapper **instead of** a bare `flutter pub get`:

```bash
./tool/pub-get.sh        # macOS / Linux / Git Bash
./tool/pub-get.ps1       # Windows PowerShell
```

Or, after a manual `flutter pub get`:

```bash
dart run tool/patch_android_plugins.dart
```

CI / pre-build verification (exits non-zero if a patch is missing or a plugin
version drifted past its snapshot):

```bash
dart run tool/patch_android_plugins.dart --check
```

### Automatic re-patching via git hooks (recommended)

Tracked hooks in [`git-hooks/`](git-hooks/) re-run the patcher after a
`git pull`/`merge` or a branch checkout — so pulling a dependency change heals
the cache automatically. They're a safe no-op when dependencies aren't fetched
yet or `dart` isn't on `PATH`.

Enable them once per clone:

```bash
git config core.hooksPath tool/git-hooks
```

That's the only setup a teammate needs. The hooks are a backstop; they do **not**
replace using `tool/pub-get.*` for `pub get` (which is when the wipe actually
happens).

### When a patched plugin is upgraded

`--check` (and a normal run) will report a version mismatch. Then:

1. Check whether the new version still needs the patch — newer plugin releases
   may drop the Built-in-Kotlin-only build script, at which point no patch is
   needed and you can delete the old snapshot.
2. If it still fails to build, create a new snapshot
   `plugin_patches/<name>-<newversion>.build.gradle.kts` (start from the pristine
   cache file and apply the same explicit-KGP change), then delete the stale one.
