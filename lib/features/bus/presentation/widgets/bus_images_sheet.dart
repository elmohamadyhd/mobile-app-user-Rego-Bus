import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

Future<void> showBusImagesSheet(
  BuildContext context, {
  required List<String> imageUrls,
}) {
  assert(imageUrls.isNotEmpty, 'imageUrls must not be empty');

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgElevated,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (sheetContext) {
      return _BusImagesSheetBody(imageUrls: imageUrls);
    },
  );
}

class _BusImagesSheetBody extends StatefulWidget {
  const _BusImagesSheetBody({required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<_BusImagesSheetBody> createState() => _BusImagesSheetBodyState();
}

class _BusImagesSheetBodyState extends State<_BusImagesSheetBody> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final urls = widget.imageUrls;
    final showDots = urls.length > 1;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.seatSelectionBusImagesTitle,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        return Semantics(
                          label: l10n.seatSelectionBusImagesPage(
                            i + 1,
                            urls.length,
                          ),
                          child: _BusImagePage(url: urls[i], l10n: l10n),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (showDots) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    urls.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: i == _index ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BusImagePage extends StatelessWidget {
  const _BusImagePage({required this.url, required this.l10n});

  final String url;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgBase,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              color: AppColors.primary,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  PhosphorIconsLight.warningCircle,
                  color: AppColors.textMuted,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.seatSelectionBusImagesError,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
