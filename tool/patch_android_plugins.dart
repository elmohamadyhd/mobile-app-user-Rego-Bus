// Re-applies AGP-9 compatibility patches to Flutter plugins in the pub cache.
//
// WHY THIS EXISTS
// ---------------
// REGO's Android build runs on the Flutter 3.44.2 *default* toolchain:
// AGP 9.0.1 + Gradle 9.1.0 + Kotlin 2.3.20, with `android.builtInKotlin=false`
// (a flag added by the Flutter template — see android/gradle.properties).
//
// Some plugins ship an android/build.gradle.kts written for AGP 9's
// "Built-in Kotlin": they use the `kotlin { compilerOptions { ... } }` accessor
// while only applying `com.android.library` — relying on AGP to provide Kotlin.
// With `builtInKotlin=false` that accessor does not exist, so the plugin's
// build script fails to COMPILE:
//
//   e: .../url_launcher_android-6.3.32/android/build.gradle.kts:35:1:
//      None of the following candidates is applicable: ... kotlin(...)
//
// The fix is to make the plugin apply the Kotlin Gradle Plugin explicitly (the
// same way jni/jni_flutter already do, which is why those build fine under
// `builtInKotlin=false`). Flipping the flag to `true` instead would fix this
// plugin but risk breaking the explicit-KGP plugins — which is exactly why the
// Flutter template ships it as `false`.
//
// The patched files live in the GLOBAL pub cache (outside this repo) and are
// wiped by `flutter pub get` (re-fetch), `dart pub cache repair`, or a plugin
// version bump. This script restores them from the known-good snapshots in
// tool/plugin_patches/, keyed by exact `<name>-<version>`.
//
// USAGE
//   dart run tool/patch_android_plugins.dart           # apply patches (idempotent)
//   dart run tool/patch_android_plugins.dart --check    # verify only; exit 1 on drift
//
// Run it after every `flutter pub get`. The tool/pub-get.* wrappers do both in
// one step. Snapshots are matched to the resolved plugin path via
// .dart_tool/package_config.json, so only plugins THIS project actually depends
// on are ever touched.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final checkOnly = args.contains('--check');
  final root = Directory.current.path;
  final configFile = File('$root/.dart_tool/package_config.json');
  final patchesDir = Directory('$root/tool/plugin_patches');

  if (!configFile.existsSync()) {
    stderr.writeln(
      'ERROR: .dart_tool/package_config.json not found. '
      'Run `flutter pub get` first.',
    );
    exit(2);
  }
  if (!patchesDir.existsSync()) {
    stderr.writeln('ERROR: ${patchesDir.path} not found.');
    exit(2);
  }

  // Discover snapshots: tool/plugin_patches/<name>-<version>.build.gradle.kts
  final snapshotRe =
      RegExp(r'^(.+)-([0-9][0-9A-Za-z.+_]*)\.build\.gradle\.kts$');
  final snapshots = <_Snapshot>[];
  for (final entity in patchesDir.listSync().whereType<File>()) {
    final name = entity.uri.pathSegments.last;
    final m = snapshotRe.firstMatch(name);
    if (m == null) continue;
    snapshots.add(_Snapshot(m.group(1)!, m.group(2)!, entity));
  }
  if (snapshots.isEmpty) {
    stdout.writeln('No plugin snapshots in ${patchesDir.path}; nothing to do.');
    return;
  }

  // Map package name -> resolved package root directory.
  final config =
      jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final resolved = <String, Directory>{};
  for (final pkg in (config['packages'] as List).cast<Map<String, dynamic>>()) {
    final rootUri = configFile.uri.resolve(pkg['rootUri'] as String);
    resolved[pkg['name'] as String] = Directory.fromUri(rootUri);
  }

  var patched = 0, upToDate = 0, drift = 0, skipped = 0;

  for (final snap in snapshots) {
    final pkgDir = resolved[snap.name];
    if (pkgDir == null) {
      stdout.writeln('· ${snap.name}: not a dependency of this project — skip');
      skipped++;
      continue;
    }

    // Guard against silent mis-patching after a version bump: the resolved
    // package dir is named "<name>-<version>".
    final resolvedName = pkgDir.uri.pathSegments
        .lastWhere((s) => s.isNotEmpty, orElse: () => '');
    final resolvedVersion = resolvedName.contains('-')
        ? resolvedName.substring(resolvedName.lastIndexOf('-') + 1)
        : '';
    if (resolvedVersion != snap.version) {
      stderr.writeln(
        '! ${snap.name}: resolved $resolvedVersion but snapshot is for '
        '${snap.version}. The AGP-9 patch may not fit the new version. '
        'Verify it still needs patching, then regenerate the snapshot as '
        'tool/plugin_patches/${snap.name}-$resolvedVersion.build.gradle.kts.',
      );
      drift++;
      continue;
    }

    final target = File('${pkgDir.path}/android/build.gradle.kts');
    if (!target.existsSync()) {
      stderr.writeln('! ${snap.name}: ${target.path} missing — skip');
      skipped++;
      continue;
    }

    final want = snap.file.readAsStringSync();
    if (target.readAsStringSync() == want) {
      stdout.writeln('✓ ${snap.name}-${snap.version}: already patched');
      upToDate++;
      continue;
    }

    if (checkOnly) {
      stderr.writeln(
        '✗ ${snap.name}-${snap.version}: cache file differs from snapshot '
        '(patch missing or reverted)',
      );
      drift++;
      continue;
    }

    target.writeAsStringSync(want);
    stdout.writeln('→ ${snap.name}-${snap.version}: patch applied');
    patched++;
  }

  stdout.writeln(
    '\n${checkOnly ? "check" : "patch"}: '
    '$patched applied, $upToDate up-to-date, $drift drift/mismatch, '
    '$skipped skipped',
  );
  if (drift > 0) exit(1);
}

class _Snapshot {
  _Snapshot(this.name, this.version, this.file);
  final String name;
  final String version;
  final File file;
}
