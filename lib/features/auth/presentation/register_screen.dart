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
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_card.dart';
import 'package:rego/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:rego/features/auth/presentation/widgets/country_picker.dart';
import 'package:rego/features/auth/presentation/widgets/phone_field.dart';
import 'package:rego/features/auth/presentation/widgets/social_row.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/gradient_hero.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  CountryCode _country = kDefaultCountry;
  bool _obscure = true;
  bool _submitting = false;
  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  bool _validate(AppLocalizations l10n) {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l10n.valRequired : null;
      _phoneError =
          Validators.isValidPhone(_phone.text) ? null : l10n.valPhone;
      _emailError =
          Validators.isValidEmail(_email.text) ? null : l10n.valEmail;
      _passwordError = Validators.isStrongEnough(_password.text)
          ? null
          : l10n.valPasswordShort;
    });
    return _nameError == null &&
        _phoneError == null &&
        _emailError == null &&
        _passwordError == null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_validate(l10n)) return;

    setState(() => _submitting = true);
    final mobile = Validators.digitsOnly(_phone.text);
    try {
      await ref.read(authRepositoryProvider).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phoneCode: _country.dial,
            mobile: mobile,
            password: _password.text,
            passwordConfirmation: _password.text,
          );
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
      _nameError = fields?['name']?.first;
      _phoneError = fields?['mobile']?.first;
      _emailError = fields?['email']?.first;
      _passwordError = fields?['password']?.first;
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
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GradientHero(
                    title: l10n.registerTitle,
                    subtitle: l10n.registerSubtitle,
                  ),
                  AuthCard(
                    gap: 13,
                    children: [
                      AuthTextField(
                        controller: _name,
                        hint: l10n.registerName,
                        icon: AppIcons.user,
                        errorText: _nameError,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      PhoneField(
                        controller: _phone,
                        country: _country,
                        hint: l10n.phoneHint,
                        onTapCountry: _pickCountry,
                        errorText: _phoneError,
                        textInputAction: TextInputAction.next,
                      ),
                      AuthTextField(
                        controller: _email,
                        hint: l10n.registerEmail,
                        icon: AppIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      AuthTextField(
                        controller: _password,
                        hint: l10n.passwordHint,
                        icon: AppIcons.lock,
                        obscure: _obscure,
                        errorText: _passwordError,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        autofillHints: const [AutofillHints.newPassword],
                        trailing: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            _obscure ? AppIcons.eye : AppIcons.eyeOff,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      PrimaryButton(
                        label: l10n.registerButton,
                        loading: _submitting,
                        onPressed: _submit,
                      ),
                      SocialRow(
                        dividerLabel: l10n.authOrSignUpWith,
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
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.registerHaveAccount,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      l10n.registerSignIn,
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
