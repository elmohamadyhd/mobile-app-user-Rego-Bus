import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/validators.dart';
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_back_button.dart';
import 'package:rego/features/auth/presentation/widgets/auth_pinned_bottom_layout.dart';
import 'package:rego/features/auth/presentation/widgets/country_picker.dart';
import 'package:rego/features/auth/presentation/widgets/icon_badge.dart';
import 'package:rego/features/auth/presentation/widgets/phone_field.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  CountryCode _country = kDefaultCountry;
  bool _submitting = false;
  String? _phoneError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _phoneError = Validators.isValidPhone(_phone.text) ? null : l10n.valPhone;
    });
    if (_phoneError != null) return;

    setState(() => _submitting = true);
    final mobile = Validators.digitsOnly(_phone.text);
    try {
      await ref.read(authRepositoryProvider).forgetPassword(
            phoneCode: _country.dial,
            mobile: mobile,
          );
      if (!mounted) return;
      unawaited(
        context.push(
          AppRoutes.otp,
          extra: OtpArgs(
            phoneCode: _country.dial,
            mobile: mobile,
            purpose: OtpPurpose.passwordReset,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _phoneError = e.errors?['mobile']?.first);
      if (e.errors == null || e.errors!.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bgElevated,
      body: SafeArea(
        child: AuthPinnedBottomLayout(
          padding: const EdgeInsets.fromLTRB(26, 8, 26, 24),
          bottomPadding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
          scrollChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthBackButton(onTap: () => context.pop()),
              const SizedBox(height: 30),
              const IconBadge(
                icon: AppIcons.lock,
                background: AppColors.secondaryTint,
                foreground: AppColors.warning,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.forgotTitle,
                style: AppTypography.h1.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.forgotSubtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              PhoneField(
                controller: _phone,
                country: _country,
                onTapCountry: _pickCountry,
                errorText: _phoneError,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
          bottom: PrimaryButton(
            label: l10n.forgotButton,
            loading: _submitting,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
