import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:safaria/features/profile/presentation/widgets/profile_avatar_picker_sheet.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_circle_avatar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';

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
  String? _pickedAvatarPath;
  bool _initialized = false;
  bool _submitting = false;
  String? _nameError;
  String? _emailError;

  bool _isPhoneVerified(AuthUser user) {
    final mobile = user.mobile?.trim();
    return mobile != null && mobile.isNotEmpty;
  }

  bool _isEmailVerified(AuthUser user) {
    final email = user.email?.trim();
    return email != null && email.isNotEmpty;
  }

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

  Future<void> _pickAvatar() async {
    final l10n = AppLocalizations.of(context);
    try {
      final path = await showProfileAvatarPickerAndPick(context);
      if (path == null || !mounted) return;
      setState(() => _pickedAvatarPath = path);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = e.code == 'channel-error'
          ? l10n.profileEditPickerRebuildRequired
          : l10n.profileEditPickerError;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool _validate(AppLocalizations l10n) {
    setState(() {
      _nameError =
          _nameController.text.trim().isEmpty ? l10n.valRequired : null;
      _emailError =
          Validators.isValidEmail(_emailController.text) ? null : l10n.valEmail;
    });
    return _nameError == null && _emailError == null;
  }

  void _applyErrors(ApiException e) {
    final fields = e.errors;
    final nameMsg = fields?['name']?.first;
    final emailMsg = fields?['email']?.first;
    setState(() {
      _nameError = nameMsg;
      _emailError = emailMsg;
    });
    final hasInline = nameMsg != null || emailMsg != null;
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
    final mobile = user.mobile?.trim() ?? '';
    final phoneCode = user.phoneCode?.trim() ?? _country.dial;

    try {
      final updated = await ref.read(profileRepositoryProvider).updateProfile(
            id: id,
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phoneCode: phoneCode,
            mobile: mobile,
            avatarPath: _pickedAvatarPath,
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
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.error,
                  size: 32,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.profileEditLoadError,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  l10n.profileEditRetry,
                  style: AppTypography.title.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formScaffold(AppLocalizations l10n, AuthUser user) {
    final avatarUrl = user.avatarUrl;
    final displayName = _nameController.text.trim();
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '?';
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

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
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg + viewInsets,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileAvatarHeader(
                        avatarUrl: avatarUrl,
                        localAvatarPath: _pickedAvatarPath,
                        initial: initial,
                        name: displayName,
                        changePhotoLabel: l10n.profileEditChangePhoto,
                        onChangePhoto: _pickAvatar,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SkylineFloatCard(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.profileEditSectionTitle,
                              style: AppTypography.overline.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _FieldLabel(text: l10n.registerName),
                            const SizedBox(height: AppSpacing.xs),
                            AuthTextField(
                              controller: _nameController,
                              hint: l10n.registerName,
                              icon: AppIcons.user,
                              errorText: _nameError,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _VerifiedFieldLabel(
                              text: l10n.registerEmail,
                              verified: _isEmailVerified(user),
                              verifiedLabel: l10n.profileEditVerified,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AuthTextField(
                              controller: _emailController,
                              hint: l10n.registerEmail,
                              icon: AppIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailError,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _VerifiedFieldLabel(
                              text: l10n.profileEditPhoneLabel,
                              verified: _isPhoneVerified(user),
                              verifiedLabel: l10n.profileEditVerified,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            PhoneField(
                              controller: _phoneController,
                              country: _country,
                              readOnly: true,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: l10n.profileEditSave,
                        icon: AppIcons.check,
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

class _ProfileAvatarHeader extends StatelessWidget {
  const _ProfileAvatarHeader({
    required this.avatarUrl,
    required this.localAvatarPath,
    required this.initial,
    required this.name,
    required this.changePhotoLabel,
    required this.onChangePhoto,
  });

  final String? avatarUrl;
  final String? localAvatarPath;
  final String initial;
  final String name;
  final String changePhotoLabel;
  final VoidCallback onChangePhoto;

  static const double _avatarSize = 96;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (localAvatarPath?.trim().isNotEmpty ?? false) ||
        (avatarUrl?.trim().isNotEmpty ?? false);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        children: [
          GestureDetector(
            onTap: onChangePhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfileCircleAvatar(
                  size: _avatarSize,
                  networkUrl: avatarUrl,
                  filePath: localAvatarPath,
                  initial: initial,
                  style: hasPhoto
                      ? ProfileCircleAvatarStyle.photo
                      : ProfileCircleAvatarStyle.brandRing,
                ),
                PositionedDirectional(
                  end: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bgCard, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      AppIcons.camera,
                      size: 16,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
         
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _VerifiedFieldLabel extends StatelessWidget {
  const _VerifiedFieldLabel({
    required this.text,
    required this.verified,
    required this.verifiedLabel,
  });

  final String text;
  final bool verified;
  final String verifiedLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _FieldLabel(text: text)),
        if (verified) _VerifiedBadge(label: verifiedLabel),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            AppIcons.shield,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
