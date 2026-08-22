import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';

/// One traveller in the list. The subtitle names what is still missing —
/// "Missing national ID" rather than a silent warning dot — so the rider
/// knows which row to open without opening all of them.
class FlightPassengerRow extends StatelessWidget {
  const FlightPassengerRow({
    super.key,
    required this.draft,
    required this.ordinal,
    required this.onTap,
    this.serverError,
  });

  final FlightPassengerDraft draft;

  /// Position within this passenger's own type, 1-based.
  final int ordinal;
  final VoidCallback onTap;

  /// A message the API pinned to this traveller, which outranks any local
  /// completeness hint.
  final String? serverError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final missing = missingFlightPassengerFields(draft);
    final complete = missing.isEmpty;
    final hasError = serverError != null;

    final name = [draft.firstName, draft.lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final slotLabel = switch (draft.type) {
      FlightPassengerType.adult => l10n.flightPassengerAdultN(ordinal),
      FlightPassengerType.child => l10n.flightPassengerChildN(ordinal),
      FlightPassengerType.infant => l10n.flightPassengerInfantN(ordinal),
    };

    final subtitle = hasError
        ? serverError!
        : complete
            ? slotLabel
            : l10n.flightPassengerMissing(_fieldLabel(l10n, missing.first));

    final (Color badgeBg, Color badgeFg, IconData badgeIcon) = hasError
        ? (
            AppColors.error.withValues(alpha: 0.12),
            AppColors.error,
            PhosphorIconsLight.warningCircle,
          )
        : complete
            ? (
                AppColors.primaryTint,
                AppColors.primary,
                PhosphorIconsLight.check,
              )
            : (
                AppColors.secondaryTint,
                AppColors.secondaryDeep,
                PhosphorIconsLight.user,
              );

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              padding: const EdgeInsetsDirectional.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: hasError
                      ? AppColors.error
                      : complete
                          ? AppColors.border
                          : AppColors.secondary,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: LtrIcon(badgeIcon, size: 20, color: badgeFg),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? slotLabel : name,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle,
                          style: AppTypography.caption.copyWith(
                            color: hasError
                                ? AppColors.error
                                : complete
                                    ? AppColors.textSecondary
                                    : AppColors.secondaryDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    PhosphorIconsLight.caretRight,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fieldLabel(
    AppLocalizations l10n,
    FlightPassengerField field,
  ) {
    return switch (field) {
      FlightPassengerField.title => l10n.flightFieldTitle,
      FlightPassengerField.firstName => l10n.flightFieldFirstName,
      FlightPassengerField.lastName => l10n.flightFieldLastName,
      FlightPassengerField.gender => l10n.flightFieldGender,
      FlightPassengerField.birthDate => l10n.flightFieldBirthDate,
      FlightPassengerField.documentNumber => l10n.flightFieldDocumentNumber,
      FlightPassengerField.nationality => l10n.flightFieldNationality,
      FlightPassengerField.residence => l10n.flightFieldResidence,
      FlightPassengerField.addressCountry => l10n.flightFieldAddressCountry,
      FlightPassengerField.addressCity => l10n.flightFieldAddressCity,
      FlightPassengerField.addressLine1 => l10n.flightFieldAddressLine1,
      FlightPassengerField.addressLine2 => l10n.flightFieldAddressLine2,
      FlightPassengerField.email => l10n.flightFieldEmail,
      FlightPassengerField.phone => l10n.flightFieldPhone,
    };
  }
}
