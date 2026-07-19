import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';

/// One spotlight step in a [CoachMarkOverlay] tour.
class CoachMarkStep {
  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.body,
  });

  final GlobalKey targetKey;
  final String title;
  final String body;
}

/// Full-screen coach overlay with a dimmed scrim, spotlight, and tooltip card.
class CoachMarkOverlay extends StatefulWidget {
  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.skipLabel,
    required this.nextLabel,
    required this.doneLabel,
    required this.onComplete,
    required this.onSkip,
  });

  final List<CoachMarkStep> steps;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;

  static const _spotlightPadding = 8.0;

  CoachMarkStep get _step => widget.steps[_index];

  bool get _isLast => _index >= widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _advance() {
    if (_isLast) {
      widget.onComplete();
      return;
    }
    setState(() => _index++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _targetRect(BuildContext context) {
    final targetContext = _step.targetKey.currentContext;
    if (targetContext == null) return null;
    final box = targetContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    final rect = offset & box.size;
    return rect.inflate(_spotlightPadding);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final spotlight = _targetRect(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (spotlight != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    spotlightRect: spotlight,
                    radius: AppRadius.card,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          if (spotlight != null)
            _CoachTooltip(
              spotlight: spotlight,
              title: _step.title,
              body: _step.body,
              skipLabel: widget.skipLabel,
              nextLabel: _isLast ? widget.doneLabel : widget.nextLabel,
              stepIndex: _index,
              stepCount: widget.steps.length,
              onSkip: widget.onSkip,
              onNext: _advance,
              animate: !reduceMotion,
            ),
        ],
      ),
    );
  }
}

class _CoachTooltip extends StatelessWidget {
  const _CoachTooltip({
    required this.spotlight,
    required this.title,
    required this.body,
    required this.skipLabel,
    required this.nextLabel,
    required this.stepIndex,
    required this.stepCount,
    required this.onSkip,
    required this.onNext,
    required this.animate,
  });

  final Rect spotlight;
  final String title;
  final String body;
  final String skipLabel;
  final String nextLabel;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final bool animate;

  static const _cardMaxWidth = 320.0;
  static const _gap = AppSpacing.md;
  // Title + ~3 body lines + actions — used to pick placement before layout.
  static const _estimatedCardHeight = 220.0;

  Widget _card(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1,
      duration: animate ? const Duration(milliseconds: 200) : Duration.zero,
      child: Material(
        color: AppColors.bgElevated,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (var i = 0; i < stepCount; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == stepIndex
                            ? AppColors.primary
                            : AppColors.hairline,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      skipLabel,
                      style: AppTypography.title.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(88, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                    ),
                    onPressed: onNext,
                    child: Text(
                      nextLabel,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boundedCard(BuildContext context, double maxHeight) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: _cardMaxWidth,
        maxHeight: maxHeight,
      ),
      child: SingleChildScrollView(
        child: _card(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    const horizontal = AppSpacing.lg;

    final spaceBelow = media.height - safe.bottom - spotlight.bottom - _gap;
    final spaceAbove = spotlight.top - safe.top - _gap;
    final centeredMaxHeight = media.height - safe.top - safe.bottom - _gap * 2;

    final Widget positioned;
    if (spaceBelow >= _estimatedCardHeight) {
      positioned = Positioned.fill(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: horizontal,
            end: horizontal,
            top: spotlight.bottom + _gap,
            bottom: safe.bottom + _gap,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: _boundedCard(context, spaceBelow),
          ),
        ),
      );
    } else if (spaceAbove >= _estimatedCardHeight) {
      positioned = Positioned.fill(
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: horizontal,
            end: horizontal,
            top: safe.top + _gap,
            bottom: media.height - spotlight.top + _gap,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _boundedCard(context, spaceAbove),
          ),
        ),
      );
    } else {
      positioned = Positioned.fill(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
            child: Center(
              child: _boundedCard(context, centeredMaxHeight),
            ),
          ),
        ),
      );
    }

    return positioned;
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.spotlightRect,
    required this.radius,
  });

  final Rect spotlightRect;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      );
    final overlay = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, Radius.circular(radius)),
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect;
  }
}
