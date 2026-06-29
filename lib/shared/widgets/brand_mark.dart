import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a brand logo (Google / Facebook / Apple) from `assets/brand/`.
///
/// Brand marks are deliberately kept out of [AppIcons]: they're multi-color
/// logos, not monochrome UI icons.
class BrandMark extends StatelessWidget {
  const BrandMark(this.asset, {super.key, this.size = 28});

  /// Filename under `assets/brand/`, e.g. [google].
  final String asset;
  final double size;

  static const google = 'google.svg';
  static const facebook = 'facebook.svg';
  static const apple = 'apple.svg';

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brand/$asset',
        width: size,
        height: size,
      );
}
