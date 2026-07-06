import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/validators.dart';
import 'package:rego/features/auth/domain/exceptions/account_not_verified_exception.dart';
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_card.dart';
import 'package:rego/features/auth/presentation/widgets/auth_pinned_bottom_layout.dart';
import 'package:rego/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:rego/features/auth/presentation/widgets/country_picker.dart';
import 'package:rego/features/auth/presentation/widgets/phone_field.dart';
import 'package:rego/features/auth/presentation/widgets/social_row.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/gradient_hero.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  CountryCode _country = kDefaultCountry;
  bool _obscure = true;
  bool _submitting = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
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
      _passwordError = _password.text.isEmpty ? l10n.valRequired : null;
    });
    if (_phoneError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    final mobile = Validators.digitsOnly(_phone.text);
    try {
      final session = await ref.read(authRepositoryProvider).login(
            phoneCode: _country.dial,
            mobile: mobile,
            password: _password.text,
          );
      await ref.read(sessionControllerProvider.notifier).setSession(session);
      if (mounted) context.go(AppRoutes.home);
    } on AccountNotVerifiedException {
      if (!mounted) return;
      unawaited(
        context.push(
          AppRoutes.otp,
          extra: OtpArgs(
            phoneCode: _country.dial,
            mobile: mobile,
            purpose: OtpPurpose.registration,
          ),
        ),
      );
    } on ApiException catch (e) {
      _applyErrors(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _applyErrors(ApiException e) {
    final fields = e.errors;
    setState(() {
      _phoneError = fields?['mobile']?.first;
      _passwordError = fields?['credentials']?.first;
    });
    if (fields == null || fields.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.bgBase,
      body: AuthPinnedBottomLayout(
        bottomPadding: const EdgeInsets.all(AppSpacing.lg),
        scrollChild: Column(
          children: [
            GradientHero(
              title: l10n.loginTitle,
              subtitle: l10n.loginSubtitle,
            ),
            AuthCard(
              children: [
                PhoneField(
                  controller: _phone,
                  country: _country,
                  onTapCountry: _pickCountry,
                  errorText: _phoneError,
                  textInputAction: TextInputAction.next,
                ),
                AuthTextField(
                  controller: _password,
                  hint: l10n.passwordHint,
                  icon: AppIcons.lock,
                  obscure: _obscure,
                  errorText: _passwordError,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.password],
                  trailing: _EyeToggle(
                    obscure: _obscure,
                    onTap: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      l10n.loginForgot,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SocialRow(
                  dividerLabel: l10n.authOrContinueWith,
                  onDisabledTap: () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.socialComingSoon)),
                    ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: l10n.loginButton,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.loginNoAccount,
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => context.push(AppRoutes.register),
                  child: Text(
                    l10n.loginSignUp,
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscure, required this.onTap});

  final bool obscure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        obscure ? AppIcons.eye : AppIcons.eyeOff,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }
}
