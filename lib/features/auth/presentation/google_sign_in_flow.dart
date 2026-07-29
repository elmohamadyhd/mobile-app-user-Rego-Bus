import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/config/app_config.dart';
import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Shared "Continue with Google" orchestration used by both [LoginScreen]
/// and [RegisterScreen] — Google auth resolves to the same
/// login-or-create-account backend call regardless of which screen the
/// button was tapped from.
Future<void> handleGoogleSignIn({
  required BuildContext context,
  required WidgetRef ref,
  required AuthGateArgs? gateArgs,
  required ValueChanged<bool> setBusy,
}) async {
  final l10n = AppLocalizations.of(context);

  if (!AppConfig.isGoogleSignInConfigured) {
    _snack(context, l10n.googleSignInFailed);
    return;
  }

  setBusy(true);
  try {
    final idToken = await ref.read(googleSignInServiceProvider).signIn();
    if (idToken == null) return; // user cancelled — no error to show

    final firebaseToken =
        await ref.read(secureStorageProvider).readOrCreateDeviceToken();
    final session =
        await ref.read(authRepositoryProvider).socialLoginWithGoogle(
              idToken: idToken,
              firebaseToken: firebaseToken,
            );
    await ref.read(sessionControllerProvider.notifier).setSession(session);
    await ref.read(guestModeProvider.notifier).disable();
    if (!context.mounted) return;

    if (session.user?.isProfileCompleted == true) {
      context.go(gateArgs?.returnTo ?? AppRoutes.home);
    } else {
      context.go(
        AppRoutes.completeProfile,
        extra: CompleteProfileArgs(returnTo: gateArgs?.returnTo),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) _snack(context, e.message);
  } catch (_) {
    if (context.mounted) _snack(context, l10n.googleSignInFailed);
  } finally {
    setBusy(false);
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
