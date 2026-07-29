import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/domain/exceptions/account_not_verified_exception.dart';
import 'package:safaria/features/auth/domain/value/otp_purpose.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/google_sign_in_flow.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_card.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_hero_layout.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_password_toggle.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_link.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:safaria/features/auth/presentation/widgets/phone_field.dart';
import 'package:safaria/features/auth/presentation/widgets/social_row.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/double_back_to_exit.dart';
import 'package:safaria/shared/widgets/language_icon_button.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.gateArgs});

  final AuthGateArgs? gateArgs;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  CountryCode _country = kDefaultCountry;
  bool _obscure = true;
  bool _submitting = false;
  bool _socialSubmitting = false;
  String? _phoneError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_clearPhoneErrorOnEdit);
    _password.addListener(_clearPasswordErrorOnEdit);
  }

  @override
  void dispose() {
    _phone
      ..removeListener(_clearPhoneErrorOnEdit)
      ..dispose();
    _password
      ..removeListener(_clearPasswordErrorOnEdit)
      ..dispose();
    super.dispose();
  }

  void _clearPhoneErrorOnEdit() {
    if (_phoneError == null) return;
    setState(() => _phoneError = null);
  }

  void _clearPasswordErrorOnEdit() {
    if (_passwordError == null) return;
    setState(() => _passwordError = null);
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  Future<void> _continueAsGuest() async {
    await ref.read(guestModeProvider.notifier).enable();
    if (mounted) context.go(AppRoutes.home);
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
      await ref.read(guestModeProvider.notifier).disable();
      if (mounted) context.go(widget.gateArgs?.returnTo ?? AppRoutes.home);
    } on AccountNotVerifiedException {
      if (!mounted) return;
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.registration,
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
    final phoneMsg = fields?['mobile']?.first;
    final passwordMsg = fields?['credentials']?.first;
    setState(() {
      _phoneError = phoneMsg;
      _passwordError = passwordMsg;
    });
    final hasInline = phoneMsg != null || passwordMsg != null;
    if (!hasInline) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DoubleBackToExit(
      alwaysIntercept: true,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.maxContentWidth,
                      ),
                      child: Column(
                        children: [
                          AuthHeroLayout(
                            title: l10n.loginTitle,
                            subtitle: l10n.loginSubtitle,
                            topEnd: const LanguageIconButton(
                              color: AppColors.onHero,
                            ),
                            child: AuthCard(
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
                                  icon: PhosphorIconsLight.lock,
                                  obscure: _obscure,
                                  errorText: _passwordError,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  autofillHints: const [
                                    AutofillHints.password,
                                  ],
                                  trailing: AuthPasswordToggle(
                                    obscure: _obscure,
                                    onTap: () => setState(
                                      () => _obscure = !_obscure,
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: AuthTextLink(
                                    label: l10n.loginForgot,
                                    onTap: () => context.push(
                                      AppRoutes.forgotPassword,
                                    ),
                                  ),
                                ),
                                PrimaryButton(
                                  label: l10n.loginButton,
                                  loading: _submitting,
                                  onPressed:
                                      _socialSubmitting ? null : _submit,
                                ),
                                SocialRow(
                                  dividerLabel: l10n.authOrContinueWith,
                                  busy: _socialSubmitting,
                                  onGoogleTap: () => handleGoogleSignIn(
                                    context: context,
                                    ref: ref,
                                    gateArgs: widget.gateArgs,
                                    setBusy: (v) =>
                                        setState(() => _socialSubmitting = v),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: Column(
                              children: [
                                PrimaryButton(
                                  label: l10n.authContinueGuest,
                                  variant: PrimaryButtonVariant.ghost,
                                  onPressed: (_submitting || _socialSubmitting)
                                      ? null
                                      : _continueAsGuest,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      l10n.loginNoAccount,
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    AuthTextLink(
                                      label: l10n.loginSignUp,
                                      style: AppTypography.body.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      onTap: () => context.push(
                                        AppRoutes.register,
                                        extra: widget.gateArgs,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
