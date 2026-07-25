import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/phone_number_formatter.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/core/utils/validators.dart';
import 'package:safaria/features/auth/domain/entities/auth_user.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:safaria/features/auth/presentation/widgets/country_picker.dart';
import 'package:safaria/features/auth/presentation/widgets/phone_field.dart';
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  CountryCode _country = kDefaultCountry;
  AuthUser? _profileUser;
  bool _initialized = false;
  bool _submitting = false;
  String? _nameError;
  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateFromUser(AuthUser user) {
    _profileUser = user;
    _nameController.text = user.name?.trim() ?? '';
    _emailController.text = user.email?.trim() ?? '';
    _country = _countryFromDial(user.phoneCode);
    _phoneController.text = _formatPhoneForField(user.mobile);
    _initialized = true;
  }

  String _formatPhoneForField(String? mobile) {
    final digits = Validators.digitsOnly(mobile ?? '');
    if (digits.isEmpty) return '';
    return formatNationalPhone(digits, _country.groupSizes);
  }

  CountryCode _countryFromDial(String? dial) {
    final normalized = dial?.trim();
    if (normalized == null || normalized.isEmpty) return kDefaultCountry;
    for (final country in kCountryCodes) {
      if (country.dial == normalized) return country;
    }
    return kDefaultCountry;
  }

  Future<void> _pickCountry() async {
    final picked = await showCountryCodePicker(context);
    if (picked != null) setState(() => _country = picked);
  }

  bool _validate(AppLocalizations l10n) {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? l10n.valRequired : null;
      _emailError =
          Validators.isValidEmail(_emailController.text) ? null : l10n.valEmail;
      _phoneError = Validators.isValidPhone(_phoneController.text)
          ? null
          : l10n.valPhone;
    });
    return _nameError == null && _emailError == null && _phoneError == null;
  }

  void _applyErrors(ApiException e) {
    final fields = e.errors;
    final nameMsg = fields?['name']?.first;
    final emailMsg = fields?['email']?.first;
    final phoneMsg = fields?['mobile']?.first ?? fields?['country_code']?.first;
    setState(() {
      _nameError = nameMsg;
      _emailError = emailMsg;
      _phoneError = phoneMsg;
    });
    final hasInline =
        nameMsg != null || emailMsg != null || phoneMsg != null;
    if (!hasInline) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _save(AppLocalizations l10n, AuthUser user) async {
    if (!_validate(l10n)) return;

    final id = user.id;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEditError)),
      );
      return;
    }

    setState(() => _submitting = true);
    final mobile = Validators.digitsOnly(_phoneController.text);

    try {
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            id: id,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phoneCode: _country.dial,
            mobile: mobile,
          );
      await ref.read(sessionControllerProvider.notifier).updateUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileEditSaved)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _applyErrors(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionUser = ref.watch(sessionControllerProvider).value?.user;

    if (sessionUser == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: ProfileAppBar(title: l10n.profileEditTitle),
        body: Center(
          child: Text(
            l10n.profileGuest,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    if (!_initialized) {
      return FutureBuilder<AuthUser>(
        future: ref.read(profileRepositoryProvider).fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _loadingScaffold(l10n);
          }
          if (snapshot.hasError) {
            return _errorScaffold(
              l10n,
              onRetry: () => setState(() {}),
            );
          }
          final user = snapshot.data ?? sessionUser;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _initialized) return;
            setState(() => _populateFromUser(user));
          });
          return _loadingScaffold(l10n);
        },
      );
    }

    return _formScaffold(l10n, _profileUser ?? sessionUser);
  }

  Widget _loadingScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: ProfileAppBar(title: l10n.profileEditTitle),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorScaffold(
    AppLocalizations l10n, {
    required VoidCallback onRetry,
  }) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: ProfileAppBar(title: l10n.profileEditTitle),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.profileEditLoadError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.profileEditRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formScaffold(AppLocalizations l10n, AuthUser user) {
    final avatarUrl = user.avatarUrl;
    final initial = _nameController.text.isNotEmpty
        ? _nameController.text.substring(0, 1)
        : '?';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: ProfileAppBar(title: l10n.profileEditTitle),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = context.isLandscape
                ? AppBreakpoints.maxContentWidth
                : constraints.maxWidth;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _Avatar(avatarUrl: avatarUrl, initial: initial)),
                      const SizedBox(height: AppSpacing.xl),
                      AuthTextField(
                        controller: _nameController,
                        hint: l10n.registerName,
                        icon: AppIcons.user,
                        errorText: _nameError,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _emailController,
                        hint: l10n.registerEmail,
                        icon: AppIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PhoneField(
                        controller: _phoneController,
                        country: _country,
                        onTapCountry: _pickCountry,
                        errorText: _phoneError,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: l10n.profileEditSave,
                        loading: _submitting,
                        onPressed:
                            _submitting ? null : () => _save(l10n, user),
                      ),
                    ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.avatarUrl, required this.initial});

  final String? avatarUrl;
  final String initial;

  static const double _size = 88;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.hairline, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialAvatar(initial: initial),
        ),
      );
    }

    return _InitialAvatar(initial: initial);
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Avatar._size,
      height: _Avatar._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryTint,
        border: Border.all(color: AppColors.hairline),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.h1.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
