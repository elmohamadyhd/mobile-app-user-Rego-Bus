import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/presentation/widgets/car_ticket_shell.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Boarding-pass search result card for a [CarTripQuote].
class CarTripTicketCard extends StatelessWidget {
  const CarTripTicketCard({
    super.key,
    required this.quote,
    required this.rounded,
    required this.onTap,
  });

  final CarTripQuote quote;
  final bool rounded;
  final VoidCallback onTap;

  static const double _stubHeight = 60;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = quote.priceFor(rounded: rounded);
    final priceText = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(price);
    const shape = CarTicketBorder(
      radius: AppRadius.xl,
      notchRadius: 10,
      notchOffsetFromBottom: _stubHeight,
      dashColor: AppColors.border,
    );

    return Material(
      color: AppColors.bgElevated,
      shape: shape,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.22),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(quote: quote, l10n: l10n),
                  const SizedBox(height: AppSpacing.md),
                  _RouteRow(quote: quote, l10n: l10n),
                ],
              ),
            ),
          ),
          SizedBox(
            height: _stubHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                0,
              ),
              child: Center(
                child: _FareStub(
                  fareLabel: l10n.tripResultsFareLabel,
                  priceText: priceText,
                  currency: quote.currency,
                  selectLabel: l10n.bookingSelect,
                  onTap: onTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.quote, required this.l10n});

  final CarTripQuote quote;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VehicleImage(quote: quote),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.company.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _vehicleSubtitle(quote),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (quote.company.refundability) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _RefundableBadge(label: l10n.carRefundable),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _vehicleSubtitle(CarTripQuote quote) {
    final model = quote.vehicle.model;
    if (model != null && model.isNotEmpty) {
      return '${quote.vehicle.categoryName} · $model';
    }
    return quote.vehicle.categoryName;
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.quote, required this.l10n});

  final CarTripQuote quote;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final from = _locationLabel(quote.fromLocation.name);
    final to = _locationLabel(quote.toLocation.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                from,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: _ConnectorLine(),
              ),
            ),
            Expanded(
              child: Text(
                to,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _SpecChip(
              icon: PhosphorIconsLight.users,
              label: l10n.carSeats(quote.vehicle.seatsNumber),
            ),
            _SpecChip(
              icon: PhosphorIconsLight.briefcase,
              label: l10n.carBags(
                quote.vehicle.bigBagsCount ?? 0,
                quote.vehicle.smallBagsCount ?? 0,
              ),
            ),
            _SpecChip(
              icon: PhosphorIconsLight.steeringWheel,
              label: _gearLabel(l10n, quote.vehicle.gearType),
            ),
          ],
        ),
      ],
    );
  }

  String _locationLabel(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  String _gearLabel(AppLocalizations l10n, String? gearType) {
    if (gearType == 'manual') return l10n.carGearManual;
    return l10n.carGearAutomatic;
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: AppSpacing.xs),
            child: Divider(
              height: 1,
              thickness: 1.5,
              color: AppColors.border,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Icon(
            PhosphorIconsLight.caretRight,
            size: 14,
            color: AppColors.primary,
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: AppSpacing.xs),
            child: Divider(
              height: 1,
              thickness: 1.5,
              color: AppColors.border,
            ),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _FareStub extends StatelessWidget {
  const _FareStub({
    required this.fareLabel,
    required this.priceText,
    required this.currency,
    required this.selectLabel,
    required this.onTap,
  });

  final String fareLabel;
  final String priceText;
  final String currency;
  final String selectLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fareLabel,
                style: AppTypography.overline.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: priceText,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' $currency',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.input),
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                selectLabel,
                style: AppTypography.body.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RefundableBadge extends StatelessWidget {
  const _RefundableBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.quote});

  final CarTripQuote quote;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final url = quote.vehicle.featuredUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [AppColors.primaryTint, AppColors.inputFill],
          ),
        ),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  PhosphorIconsLight.car,
                  color: AppColors.primary,
                  size: 28,
                ),
              )
            : const Icon(
                PhosphorIconsLight.car,
                color: AppColors.primary,
                size: 28,
              ),
      ),
    );
  }
}
