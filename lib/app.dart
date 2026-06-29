import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/providers/locale_controller.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/l10n/app_localizations.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light, // Skyline is a light-first design.
      locale: locale, // Device default unless user overrides via settings.
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      // Default the status bar to dark icons (light screens); the blue/hero
      // screens override this to white icons via a nested AnnotatedRegion.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.statusBarDark,
        child: child!,
      ),
    );
  }
}
