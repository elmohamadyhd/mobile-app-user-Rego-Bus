import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/phone_number_formatter.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Phone input with a tappable country-code chip, matching the Skyline design.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.country,
    this.onTapCountry,
    this.errorText,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final CountryCode country;
  final VoidCallback? onTapCountry;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool readOnly;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  @override
  void initState() {
    super.initState();
    _reformatController(widget.country.groupSizes);
  }

  @override
  void didUpdateWidget(covariant PhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.country.dial != widget.country.dial) {
      _reformatController(widget.country.groupSizes);
    }
  }

  void _reformatController(List<int> groupSizes) {
    final digits = Validators.digitsOnly(widget.controller.text);
    if (digits.isEmpty) return;
    final formatted = formatNationalPhone(
      digits,
      groupSizes,
      dial: widget.country.dial,
    );
    if (formatted == widget.controller.text) return;
    widget.controller.value = widget.controller.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: widget.readOnly
                ? AppColors.hairline.withValues(alpha: 0.55)
                : AppColors.inputFill,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(
              color: hasError ? AppColors.error : AppColors.hairline,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                _CountryChip(
                  country: widget.country,
                  onTap: widget.readOnly ? null : widget.onTapCountry,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: TextInputType.phone,
                    textInputAction: widget.textInputAction,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    onSubmitted: widget.onSubmitted,
                    readOnly: widget.readOnly,
                    autofillHints: const [AutofillHints.telephoneNumberLocal],
                    inputFormatters: widget.readOnly
                        ? null
                        : [
                            NationalPhoneInputFormatter(
                              groupSizes: widget.country.groupSizes,
                              dial: widget.country.dial,
                            ),
                          ],
                    style: AppTypography.body.copyWith(
                      color: widget.readOnly
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.country.sampleHint,
                      hintStyle: AppTypography.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.sm - 2,
              start: AppSpacing.sm - 2,
              end: AppSpacing.sm - 2,
            ),
            child: Text(
              widget.errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.country, this.onTap});

  final CountryCode country;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 1,
        vertical: AppSpacing.sm - 1,
      ),
      decoration: BoxDecoration(
        color: onTap == null
            ? AppColors.hairline.withValues(alpha: 0.45)
            : AppColors.bgCard,
        borderRadius: radius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(country.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.sm - 2),
          Text(
            '+${country.dial}',
            style: AppTypography.caption.copyWith(
              color:
                  onTap == null ? AppColors.textMuted : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              PhosphorIconsLight.caretDown,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return chip;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: chip,
        ),
      ),
    );
  }
}
