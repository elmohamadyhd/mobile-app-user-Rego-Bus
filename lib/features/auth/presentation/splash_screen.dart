import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Minimum time the brand splash stays visible so users can see it.
const kMinSplashDuration = Duration(seconds: 2);

/// Brand splash that also bootstraps the session: once the stored session
/// resolves, it routes to Home (signed in), Onboarding (first run), or Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;
  late final DateTime _splashStartedAt = DateTime.now();

  Future<void> _route(AsyncValue<AuthSession?> session) async {
    if (_navigated) return;
    if (!session.hasValue) return;

    _navigated = true;
    final value = session.requireValue;

    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = kMinSplashDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarLight,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SizedBox.expand(
            child: Stack(
              children: [
                // Skyline decorative "blobs".
                Positioned(
                  top: -56,
                  right: -44,
                  child: _circle(210, Colors.white.withValues(alpha: 0.08)),
                ),
                Positioned(
                  bottom: 120,
                  left: -34,
                  child: _circle(120, Colors.white.withValues(alpha: 0.06)),
                ),
                Positioned(
                  bottom: 230,
                  right: 34,
                  child:
                      _circle(74, AppColors.secondary.withValues(alpha: 0.16)),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glassy rounded badge holding the brand mark.
                      Container(
                        width: 108,
                        height: 108,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: SvgPicture.asset(
                          'assets/new-logo-white.svg',
                          width: 62,
                          height: 62,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Image.asset(
                        'assets/rego-wordmark-white.png',
                        width: 194,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.appTagline,
                        style: AppTypography.title.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onHero.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 48),
                      child: _LoadingDots(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Three softly pulsing dots, staggered — the Skyline loading indicator.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final phase = (_controller.value - i * 0.16) % 1.0;
            final t = (1 - math.cos(phase * 2 * math.pi)) / 2; // 0 → 1 → 0
            return Transform.scale(
              scale: 0.78 + 0.22 * t,
              child: Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.symmetric(horizontal: 4.5),
                decoration: BoxDecoration(
                  color: AppColors.onHero.withValues(alpha: 0.4 + 0.6 * t),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
