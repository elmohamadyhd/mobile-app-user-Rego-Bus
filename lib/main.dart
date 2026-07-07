import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/app.dart';
import 'package:rego/core/theme/app_theme.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  // First screen (splash) is the blue hero — start with white status icons.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.statusBarLight);
  await dotenv.load();
  runApp(const ProviderScope(child: App()));
}
