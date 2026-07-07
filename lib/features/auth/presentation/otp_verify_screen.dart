import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/auth/domain/value/otp_purpose.dart';
import 'package:rego/features/auth/presentation/auth_flow_args.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/auth_back_button.dart';
import 'package:rego/features/auth/presentation/widgets/auth_pinned_bottom_layout.dart';
import 'package:rego/features/auth/presentation/widgets/icon_badge.dart';
import 'package:rego/features/auth/presentation/widgets/otp_input.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/ltr_text.dart';
import 'package:rego/shared/widgets/primary_button.dart';

const _otpLength = 4;
const _resendSeconds = 59;

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  String _code = '';
  bool _submitting = false;
  bool _hasError = false;
  int _secondsLeft = _resendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _phoneLabel => '+${widget.args.phoneCode} ${widget.args.mobile}';

  Future<void> _confirm() async {
    if (_code.length < _otpLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _submitting = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (widget.args.purpose == OtpPurpose.registration) {
        final session = await repo.verifyOtp(
          phoneCode: widget.args.phoneCode,
          mobile: widget.args.mobile,
          code: _code,
        );
        await ref.read(sessionControllerProvider.notifier).setSession(session);
        await ref.read(guestModeProvider.notifier).disable();
        if (mounted) {
          context.go(widget.args.returnTo ?? AppRoutes.home);
        }
      } else {
        await repo.validateOtp(
          phoneCode: widget.args.phoneCode,
          mobile: widget.args.mobile,
          code: _code,
        );
        if (!mounted) return;
        unawaited(
          context.push(
            AppRoutes.newPassword,
            extra: ResetArgs(
              phoneCode: widget.args.phoneCode,
              mobile: widget.args.mobile,
              code: _code,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _hasError = true);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).resendOtp(
            phoneCode: widget.args.phoneCode,
            mobile: widget.args.mobile,
          );
      if (!mounted) return;
      _startTimer();
      _snack(l10n.otpResent);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                icon: AppIcons.mail,
                background: AppColors.primaryTint,
                foreground: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.otpTitle,
                style: AppTypography.h1.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.otpSubtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              LtrText(
                _phoneLabel,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 30),
              OtpInput(
                length: _otpLength,
                hasError: _hasError,
                onChanged: (v) => setState(() {
                  _code = v;
                  _hasError = false;
                }),
                onCompleted: (_) => _confirm(),
              ),
              const SizedBox(height: 24),
              Center(
                child: _secondsLeft > 0
                    ? Text.rich(
                        TextSpan(
                          text: '${l10n.otpResendIn} ',
                          style: AppTypography.body
                              .copyWith(color: AppColors.textMuted),
                          children: [
                            TextSpan(
                              text: _formatTime(_secondsLeft),
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: Text(
                          l10n.otpResend,
                          style: AppTypography.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          bottom: PrimaryButton(
            label: l10n.commonConfirm,
            loading: _submitting,
            onPressed: _confirm,
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
