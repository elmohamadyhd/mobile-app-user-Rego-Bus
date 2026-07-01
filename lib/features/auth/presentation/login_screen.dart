import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/validators.dart';
import 'package:rego/features/auth/domain/entities/auth_session.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_card.dart';
import 'package:rego/features/auth/presentation/widgets/auth_text_field.dart';
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
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final identifier = _identifier.text.trim();
    setState(() {
      _identifierError = _identifierErrorFor(identifier, l10n);
      _passwordError = _password.text.isEmpty ? l10n.valRequired : null;
    });
    if (_identifierError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    try {
      // DEV BYPASS: the login API isn't wired up yet — mint a mock session
      // and drop straight into Home instead of calling the backend.
      await ref
          .read(sessionControllerProvider.notifier)
          .setSession(const AuthSession(token: 'dev-mock-token'));
      if (mounted) context.go(AppRoutes.home);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// design/V1 shows one "Phone or email" field, but the backend login is
  /// phone-only — email entries get a friendly "coming soon" until it lands.
  String? _identifierErrorFor(String value, AppLocalizations l10n) {
    if (value.isEmpty) return l10n.valRequired;
    if (value.contains('@')) return l10n.loginEmailUnsupported;
    return Validators.isValidPhone(value) ? null : l10n.valPhone;
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
                    title: l10n.loginTitle,
                    subtitle: l10n.loginSubtitle,
                  ),
                  AuthCard(
                    children: [
                      AuthTextField(
                        controller: _identifier,
                        hint: l10n.loginIdentifierHint,
                        icon: AppIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _identifierError,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
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
                      PrimaryButton(
                        label: l10n.loginButton,
                        loading: _submitting,
                        onPressed: _submit,
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
                    l10n.loginNoAccount,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted),
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
            ),
          ),
        ],
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
