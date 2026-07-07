import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_theme.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/l10n/app_localizations.dart';

/// Minimum time the brand splash stays visible so users can see it.
const kMinSplashDuration = Duration(seconds: 2);

/// Intro morph from the native splash frame into the full brand lockup.
const _introDuration = Duration(milliseconds: 1000);

/// Pin size on frame 0 — tuned to match [assets/native_splash_logo.png].
const _nativePinSize = 80.0;

const _finalBadgeSize = 108.0;
const _finalPinSize = 62.0;

/// Pushes the lockup down so the bare pin sits at true screen center on frame 0.
const _lockupSettleOffset = 72.0;

/// Brand splash that also bootstraps the session: once the stored session
/// and guest-mode flag resolve, it routes to Home (signed in or guest),
/// Onboarding (first run), or Login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  late final DateTime _splashStartedAt = DateTime.now();
  late final Completer<void> _introComplete = Completer<void>();

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: _introDuration,
  );

  late final Animation<double> _bg = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );

  late final Animation<double> _badge = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.15, 0.6, curve: Curves.easeOutBack),
  );

  late final Animation<double> _settle = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
  );

  late final Animation<double> _text = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
  );

  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.15),
    end: Offset.zero,
  ).animate(_text);

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_introComplete.isCompleted) {
        _introComplete.complete();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _intro.forward();
      _route(
        ref.read(sessionControllerProvider),
        ref.read(guestModeProvider),
      );
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _route(
    AsyncValue<AuthSession?> session,
    AsyncValue<bool> guestMode,
  ) async {
    if (_navigated) return;
    if (!session.hasValue || !guestMode.hasValue) return;

    if (!_introComplete.isCompleted) {
      await _introComplete.future;
    }
    if (!mounted || _navigated) return;

    _navigated = true;
    final value = session.requireValue;
    final isGuest = guestMode.requireValue;

    final elapsed = DateTime.now().difference(_splashStartedAt);
    final remaining = kMinSplashDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    if (!mounted) return;

    if (value != null || isGuest) {
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
    ref.listen(
      sessionControllerProvider,
      (_, next) => _route(next, ref.read(guestModeProvider)),
    );
    ref.listen(
      guestModeProvider,
      (_, next) => _route(ref.read(sessionControllerProvider), next),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarLight,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final settleOffset = _lockupSettleOffset * (1 - _settle.value);
            final badgeSize =
                lerpDouble(_nativePinSize, _finalBadgeSize, _badge.value)!;
            final pinSize =
                lerpDouble(_nativePinSize, _finalPinSize, _badge.value)!;
            final glassAlpha = 0.16 * _badge.value;
            final borderAlpha = 0.22 * _badge.value;
            final badgeRadius = lerpDouble(0, AppRadius.sheet, _badge.value)!;

            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.primary),
                FadeTransition(
                  opacity: _bg,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -56,
                          right: -44,
                          child: _circle(
                            210,
                            Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        Positioned(
                          bottom: 120,
                          left: -34,
                          child: _circle(
                            120,
                            Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        Positioned(
                          bottom: 230,
                          right: 34,
                          child: _circle(
                            74,
                            AppColors.secondary.withValues(alpha: 0.16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, settleOffset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: badgeSize,
                          height: badgeSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: glassAlpha),
                            borderRadius: BorderRadius.circular(badgeRadius),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: borderAlpha,
                              ),
                            ),
                          ),
                          child: SvgPicture.asset(
                            'assets/new-logo-white.svg',
                            width: pinSize,
                            height: pinSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                        FadeTransition(
                          opacity: _text,
                          child: SlideTransition(
                            position: _textSlide,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                                    color: AppColors.onHero.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                      child: FadeTransition(
                        opacity: _text,
                        child: SlideTransition(
                          position: _textSlide,
                          child: const _LoadingDots(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
