import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Brand splash that also bootstraps the session: once the stored session
/// resolves, it routes to Home (signed in), Onboarding (first run), or Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  Future<void> _route(AsyncValue<AuthSession?> session) async {
    if (_navigated) return;
    if (!session.hasValue) return;

    _navigated = true;
    final value = session.requireValue;
    if (!mounted) return;

    if (value != null) {
      context.go(AppRoutes.home);
      return;
    }
    final seen = await ref.read(secureStorageProvider).onboardingSeen();
    if (!mounted) return;
    context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(sessionControllerProvider, (_, next) => _route(next));

    final session = ref.watch(sessionControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _route(session));

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/rego-wordmark-white.png',
                width: 168,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.appTagline,
                style: AppTypography.title.copyWith(
                  color: AppColors.onHero.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              const _LoadingDots(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.onHero.withValues(alpha: i == 1 ? 0.9 : 0.4),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
