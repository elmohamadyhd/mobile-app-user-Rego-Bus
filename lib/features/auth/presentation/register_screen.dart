import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/storage/secure_storage.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/domain/value/otp_purpose.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_card.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_hero_layout.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_password_toggle.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_pinned_bottom_layout.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:safaria/features/auth/presentation/widgets/phone_field.dart';
import 'package:safaria/features/auth/presentation/widgets/social_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.gateArgs});

  final AuthGateArgs? gateArgs;

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
  void initState() {
    super.initState();
    _name.addListener(_clearNameErrorOnEdit);
    _phone.addListener(_clearPhoneErrorOnEdit);
    _email.addListener(_clearEmailErrorOnEdit);
    _password.addListener(_clearPasswordErrorOnEdit);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_clearNameErrorOnEdit)
      ..dispose();
    _phone
      ..removeListener(_clearPhoneErrorOnEdit)
      ..dispose();
    _email
      ..removeListener(_clearEmailErrorOnEdit)
      ..dispose();
    _password
      ..removeListener(_clearPasswordErrorOnEdit)
      ..dispose();
    super.dispose();
  }

  void _clearNameErrorOnEdit() {
    if (_nameError == null) return;
    setState(() => _nameError = null);
  }

  void _clearPhoneErrorOnEdit() {
    if (_phoneError == null) return;
    setState(() => _phoneError = null);
  }

  void _clearEmailErrorOnEdit() {
    if (_emailError == null) return;
    setState(() => _emailError = null);
  }

  void _clearPasswordErrorOnEdit() {
    if (_passwordError == null) return;
    setState(() => _passwordError = null);
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  bool _validate(AppLocalizations l10n) {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l10n.valRequired : null;
      _phoneError = Validators.isValidPhone(_phone.text) ? null : l10n.valPhone;
      _emailError = Validators.isValidEmail(_email.text) ? null : l10n.valEmail;
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
      final firebaseToken =
          await ref.read(secureStorageProvider).readOrCreateDeviceToken();
      await ref.read(authRepositoryProvider).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phoneCode: _country.dial,
            mobile: mobile,
            password: _password.text,
            passwordConfirmation: _password.text,
            firebaseToken: firebaseToken,
          );
      if (!mounted) return;
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.registration,
          returnTo: widget.gateArgs?.returnTo,
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
    final nameMsg = fields?['name']?.first;
    final phoneMsg = fields?['mobile']?.first;
    final emailMsg = fields?['email']?.first;
    final passwordMsg = fields?['password']?.first;
    setState(() {
      _nameError = nameMsg;
      _phoneError = phoneMsg;
      _emailError = emailMsg;
      _passwordError = passwordMsg;
    });
    final hasInline = nameMsg != null ||
        phoneMsg != null ||
        emailMsg != null ||
        passwordMsg != null;
    if (!hasInline) {
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
            AuthHeroLayout(
              title: l10n.registerTitle,
              subtitle: l10n.registerSubtitle,
              child: AuthCard(
                children: [
                  AuthTextField(
                    controller: _name,
                    hint: l10n.registerName,
                    icon: PhosphorIconsLight.user,
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                  ),
                  PhoneField(
                    controller: _phone,
                    country: _country,
                    onTapCountry: _pickCountry,
                    errorText: _phoneError,
                    textInputAction: TextInputAction.next,
                  ),
                  AuthTextField(
                    controller: _email,
                    hint: l10n.registerEmail,
                    icon: PhosphorIconsLight.envelopeSimple,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                  ),
                  AuthTextField(
                    controller: _password,
                    hint: l10n.passwordHint,
                    icon: PhosphorIconsLight.lock,
                    obscure: _obscure,
                    errorText: _passwordError,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    autofillHints: const [AutofillHints.newPassword],
                    trailing: AuthPasswordToggle(
                      obscure: _obscure,
                      onTap: () => setState(() => _obscure = !_obscure),
                    ),
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
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: l10n.registerButton,
              loading: _submitting,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.registerHaveAccount,
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                AuthTextLink(
                  label: l10n.registerSignIn,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  onTap: () => context.pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
