import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/phone_number_formatter.dart';
import 'package:rego/core/utils/validators.dart';
import 'package:rego/features/auth/presentation/widgets/country_picker.dart';

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
  });

  final TextEditingController controller;
  final CountryCode country;
  final VoidCallback? onTapCountry;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

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
    final formatted = formatNationalPhone(digits, groupSizes);
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
            color: AppColors.inputFill,
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
                  onTap: widget.onTapCountry,
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
                    autofillHints: const [AutofillHints.telephoneNumberLocal],
                    inputFormatters: [
                      NationalPhoneInputFormatter(
                        groupSizes: widget.country.groupSizes,
                      ),
                    ],
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
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
            padding: const EdgeInsets.only(top: 6, left: 6, right: 6),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              '+${country.dial}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(
                AppIcons.chevronDown,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
