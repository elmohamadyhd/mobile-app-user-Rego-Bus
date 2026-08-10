import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/providers/locale_controller.dart';
import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/profile/presentation/providers/profile_providers.dart';
import 'package:safaria/features/profile/presentation/widgets/profile_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/language_picker_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _languageAutonym(String languageCode) =>
      languageCode == 'ar' ? 'العربية' : 'English';

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _DeleteAccountDialog(),
    );
    if (deleted != true || !context.mounted) return;

    await ref.read(sessionControllerProvider.notifier).logout();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = ref.watch(localeControllerProvider).languageCode;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    final session = ref.watch(sessionControllerProvider).value;
    final showDelete = !isGuest && session != null;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: ProfileAppBar(title: l10n.profileMenuSettings),
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
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg + viewInsets,
                  ),
                  child: _SettingsMenuCard(
                    children: [
                      _SettingsLanguageTile(
                        label: l10n.profileMenuLanguage,
                        value: _languageAutonym(languageCode),
                        onTap: () => showLanguagePickerSheet(context),
                      ),
                      if (showDelete) ...[
                        const Divider(
                          color: AppColors.hairline,
                          height: 1,
                          indent: AppSpacing.lg + 40 + AppSpacing.md,
                        ),
                        _SettingsDeleteTile(
                          label: l10n.settingsDeleteAccount,
                          onTap: () => _confirmDeleteAccount(context, ref),
                        ),
                      ],
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

class _SettingsMenuCard extends StatelessWidget {
  const _SettingsMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.20),
            blurRadius: 40,
            spreadRadius: -18,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsLanguageTile extends StatelessWidget {
  const _SettingsLanguageTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  PhosphorIconsLight.translate,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                PhosphorIconsLight.caretRight,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDeleteTile extends StatelessWidget {
  const _SettingsDeleteTile({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  PhosphorIconsLight.trash,
                  size: 22,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                PhosphorIconsLight.caretRight,
                size: 20,
                color: AppColors.error.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matchesConfirmWord(String word) => _controller.text.trim() == word;

  bool _isAsciiWord(String word) => RegExp(r'^[\x00-\x7F]+$').hasMatch(word);

  Future<void> _submit(String word) async {
    if (!_matchesConfirmWord(word) || _submitting) return;

    setState(() => _submitting = true);
    final l10n = AppLocalizations.of(context);

    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
              content: Text(e.message.isNotEmpty
                  ? e.message
                  : l10n.settingsDeleteAccountFailed)),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.settingsDeleteAccountFailed)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final word = l10n.settingsDeleteAccountConfirmWord;
    final matches = _matchesConfirmWord(word);
    final field = TextField(
      controller: _controller,
      enabled: !_submitting,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: word,
      ),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      title: Text(l10n.settingsDeleteAccountTitle, style: AppTypography.h2),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsDeleteAccountMessage,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.settingsDeleteAccountTypePrompt(word),
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_isAsciiWord(word))
              Directionality(
                textDirection: TextDirection.ltr,
                child: field,
              )
            else
              field,
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            l10n.settingsDeleteAccountCancel,
            style: AppTypography.title.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: matches && !_submitting ? () => _submit(word) : null,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  l10n.settingsDeleteAccountConfirm,
                  style: AppTypography.title.copyWith(
                    color: matches ? AppColors.error : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}
