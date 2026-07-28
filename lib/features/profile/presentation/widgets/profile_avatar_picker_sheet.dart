import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

enum ProfileAvatarSource { gallery, camera }

final ImagePicker _profileImagePicker = ImagePicker();

/// Shows the source sheet, waits for it to dismiss, then opens the native
/// picker. Deferring the native call avoids Android channel races when the
/// modal route is still closing.
Future<String?> showProfileAvatarPickerAndPick(BuildContext context) async {
  final source = await showProfileAvatarPickerSheet(context);
  if (source == null) return null;

  // Let the bottom sheet finish dismissing before opening native UI.
  await Future<void>.delayed(const Duration(milliseconds: 200));

  return pickProfileAvatarImage(source);
}

/// Bottom sheet for choosing a new profile photo.
Future<ProfileAvatarSource?> showProfileAvatarPickerSheet(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);

  return showModalBottomSheet<ProfileAvatarSource>(
    context: context,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.profileEditChangePhoto,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AvatarPickerTile(
              icon: PhosphorIconsLight.image,
              label: l10n.profileEditPickGallery,
              onTap: () => Navigator.of(context).pop(ProfileAvatarSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AvatarPickerTile(
              icon: PhosphorIconsLight.camera,
              label: l10n.profileEditPickCamera,
              onTap: () => Navigator.of(context).pop(ProfileAvatarSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarPickerTile extends StatelessWidget {
  const _AvatarPickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputFill,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
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
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks an image from [source] and returns its local file path, or null.
Future<String?> pickProfileAvatarImage(ProfileAvatarSource source) async {
  try {
    final file = await _profileImagePicker.pickImage(
      source: source == ProfileAvatarSource.gallery
          ? ImageSource.gallery
          : ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.path;
  } on PlatformException catch (e) {
    if (e.code == 'channel-error') {
      throw PlatformException(
        code: e.code,
        message: 'image_picker native plugin is not linked. '
            'Stop the app and run a full rebuild (not hot reload).',
      );
    }
    rethrow;
  }
}
