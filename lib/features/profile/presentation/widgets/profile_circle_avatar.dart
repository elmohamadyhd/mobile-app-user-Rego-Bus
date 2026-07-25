import 'dart:io';

import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_typography.dart';

enum ProfileCircleAvatarStyle {
  /// Neutral ring for edit screen / photo avatars.
  photo,

  /// White hairline over the blue hero (profile tab).
  hero,

  /// Skyline gradient ring for letter fallbacks.
  brandRing,
}

/// Circular profile avatar with reliable [ClipOval] clipping.
///
/// Avoids [BoxDecoration] box shadows on circle shapes — they rasterize as
/// faceted polygons on some Android GPUs.
class ProfileCircleAvatar extends StatelessWidget {
  const ProfileCircleAvatar({
    super.key,
    required this.size,
    this.networkUrl,
    this.filePath,
    this.initial = '?',
    this.style = ProfileCircleAvatarStyle.photo,
  });

  final double size;
  final String? networkUrl;
  final String? filePath;
  final String initial;
  final ProfileCircleAvatarStyle style;

  @override
  Widget build(BuildContext context) {
    final image = _AvatarImageContent(
      size: _innerSize,
      networkUrl: networkUrl,
      filePath: filePath,
      initial: initial,
      initialBackground: _initialBackground,
      initialForeground: _initialForeground,
    );

    return SizedBox(
      width: size,
      height: size,
      child: switch (style) {
        ProfileCircleAvatarStyle.brandRing => _BrandRingFrame(
            size: size,
            innerSize: _innerSize,
            child: image,
          ),
        ProfileCircleAvatarStyle.hero => _HeroFrame(
            size: size,
            innerSize: _innerSize,
            child: image,
          ),
        ProfileCircleAvatarStyle.photo => _PhotoFrame(
            size: size,
            innerSize: _innerSize,
            child: image,
          ),
      },
    );
  }

  double get _innerSize => size - _frameInset * 2;

  double get _frameInset => switch (style) {
        ProfileCircleAvatarStyle.brandRing => 5,
        ProfileCircleAvatarStyle.hero => 2,
        ProfileCircleAvatarStyle.photo => 2,
      };

  Color get _initialBackground => switch (style) {
        ProfileCircleAvatarStyle.hero =>
          Colors.white.withValues(alpha: 0.18),
        ProfileCircleAvatarStyle.brandRing => AppColors.primaryTint,
        ProfileCircleAvatarStyle.photo => AppColors.primaryTint,
      };

  Color get _initialForeground => switch (style) {
        ProfileCircleAvatarStyle.hero => AppColors.onHero,
        ProfileCircleAvatarStyle.brandRing => AppColors.primary,
        ProfileCircleAvatarStyle.photo => AppColors.primary,
      };
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    required this.size,
    required this.innerSize,
    required this.child,
  });

  final double size;
  final double innerSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline, width: 2),
        ),
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({
    required this.size,
    required this.innerSize,
    required this.child,
  });

  final double size;
  final double innerSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: innerSize,
        height: innerSize,
        foregroundDecoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 2,
          ),
        ),
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _BrandRingFrame extends StatelessWidget {
  const _BrandRingFrame({
    required this.size,
    required this.innerSize,
    required this.child,
  });

  final double size;
  final double innerSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.heroGradient,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.bgCard,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarImageContent extends StatelessWidget {
  const _AvatarImageContent({
    required this.size,
    required this.networkUrl,
    required this.filePath,
    required this.initial,
    required this.initialBackground,
    required this.initialForeground,
  });

  final double size;
  final String? networkUrl;
  final String? filePath;
  final String initial;
  final Color initialBackground;
  final Color initialForeground;

  @override
  Widget build(BuildContext context) {
    final localPath = filePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _InitialContent(
          size: size,
          initial: initial,
          background: initialBackground,
          foreground: initialForeground,
        ),
      );
    }

    final url = networkUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _InitialContent(
          size: size,
          initial: initial,
          background: initialBackground,
          foreground: initialForeground,
        ),
      );
    }

    return _InitialContent(
      size: size,
      initial: initial,
      background: initialBackground,
      foreground: initialForeground,
    );
  }
}

class _InitialContent extends StatelessWidget {
  const _InitialContent({
    required this.size,
    required this.initial,
    required this.background,
    required this.foreground,
  });

  final double size;
  final String initial;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            initial,
            style: AppTypography.h1.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
