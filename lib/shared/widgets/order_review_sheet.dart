import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Opens the shared order-review bottom sheet.
Future<void> showOrderReviewSheet(
  BuildContext context, {
  required Future<void> Function(int rating, String? comment) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    builder: (context) => _OrderReviewSheet(onSubmit: onSubmit),
  );
}

class _OrderReviewSheet extends StatefulWidget {
  const _OrderReviewSheet({required this.onSubmit});

  final Future<void> Function(int rating, String? comment) onSubmit;

  @override
  State<_OrderReviewSheet> createState() => _OrderReviewSheetState();
}

class _OrderReviewSheetState extends State<_OrderReviewSheet> {
  int? _rating;
  final _commentController = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rating = _rating;
    if (rating == null || _loading) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final raw = _commentController.text.trim();
      await widget.onSubmit(rating, raw.isEmpty ? null : raw);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      final lower = e.message.toLowerCase();
      final message = lower.contains('completed')
          ? l10n.orderReviewNotAllowedError
          : l10n.orderReviewSubmitError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.orderReviewSubmitError)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.orderReviewSheetTitle,
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          key: ValueKey('order-review-star-$i'),
                          onPressed: _loading
                              ? null
                              : () => setState(() => _rating = i),
                          icon: Icon(
                            PhosphorIconsLight.star,
                            size: 32,
                            color: (_rating ?? 0) >= i
                                ? AppColors.secondary
                                : AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _commentController,
                    enabled: !_loading,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l10n.orderReviewCommentHint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l10n.orderReviewSubmit,
                    loading: _loading,
                    onPressed: _rating == null ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
