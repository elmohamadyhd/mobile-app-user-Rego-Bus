import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/domain/value/otp_purpose.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_card.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_hero_layout.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:safaria/features/auth/presentation/widgets/phone_field.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// Blocking step after a brand-new Google sign-up: the backend has no phone
/// on file for this account yet (`isProfileCompleted == false`), so the
/// router guard sends every signed-in-but-incomplete session here. There is
/// deliberately no back button — this mirrors the existing router guard
/// pattern (guest/login) rather than adding a new escape hatch.
class CompletePhoneScreen extends ConsumerStatefulWidget {
  const CompletePhoneScreen({super.key, this.args});

  final CompleteProfileArgs? args;

  @override
  ConsumerState<CompletePhoneScreen> createState() =>
      _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends ConsumerState<CompletePhoneScreen> {
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
      await ref.read(authRepositoryProvider).sendOtp(
            phoneCode: _country.dial,
            mobile: mobile,
          );
      if (!mounted) return;
      await context.push(
        AppRoutes.otp,
        extra: OtpArgs(
          phoneCode: _country.dial,
          mobile: mobile,
          purpose: OtpPurpose.linkGoogleAccountPhone,
          returnTo: widget.args?.returnTo,
        ),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
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
                    child: AuthHeroLayout(
                      title: l10n.completeProfileTitle,
                      subtitle: l10n.completeProfileSubtitle,
                      child: AuthCard(
                        children: [
                          PhoneField(
                            controller: _phone,
                            country: _country,
                            onTapCountry: _pickCountry,
                            errorText: _phoneError,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          PrimaryButton(
                            label: l10n.commonConfirm,
                            loading: _submitting,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
