import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/validators.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_back_button.dart';
import 'package:rego/features/auth/presentation/widgets/auth_pinned_bottom_layout.dart';
import 'package:rego/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:rego/features/auth/presentation/widgets/icon_badge.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key, required this.args});

  final ResetArgs args;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _passwordError = Validators.isStrongEnough(_password.text)
          ? null
          : l10n.valPasswordShort;
      _confirmError =
          _confirm.text == _password.text ? null : l10n.valPasswordMatch;
    });
    if (_passwordError != null || _confirmError != null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            phoneCode: widget.args.phoneCode,
            mobile: widget.args.mobile,
            code: widget.args.code,
            password: _password.text,
            passwordConfirmation: _confirm.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.newPasswordDone)));
      context.go(AppRoutes.login);
    } on ApiException catch (e) {
      final passwordMsg = e.errors?['password']?.first;
      setState(() => _passwordError = passwordMsg);
      if (passwordMsg == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _eye() => GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        behavior: HitTestBehavior.opaque,
        child: Icon(
          _obscure ? AppIcons.eye : AppIcons.eyeOff,
          size: 20,
          color: AppColors.textMuted,
        ),
      );

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
                icon: AppIcons.shield,
                background: AppColors.primaryTint,
                foreground: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.newPasswordTitle,
                style: AppTypography.h1.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.newPasswordSubtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              AuthTextField(
                controller: _password,
                hint: l10n.newPasswordHint,
                icon: AppIcons.lock,
                obscure: _obscure,
                errorText: _passwordError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                trailing: _eye(),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirm,
                hint: l10n.confirmPasswordHint,
                icon: AppIcons.lock,
                obscure: _obscure,
                errorText: _confirmError,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.newPassword],
                trailing: _eye(),
              ),
            ],
          ),
          bottom: PrimaryButton(
            label: l10n.newPasswordButton,
            loading: _submitting,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
