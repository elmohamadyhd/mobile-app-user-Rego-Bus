import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_chip.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class BusTripDetailsScreen extends ConsumerWidget {
  const BusTripDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final (tripDetail, status) = ref.watch(
      busBookingProvider.select((s) => (s.tripDetail, s.status)),
    );

    if (status == BusBookingStatus.loadingDetail || tripDetail == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(title: l10n.tripDetailTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.tripDetailTitle),
      bottomNavigationBar: _PriceFooter(
        priceEgp: tripDetail.summary.priceEgp,
        l10n: l10n,
        onChooseSeats: () => context.push(BusRoutes.seats),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OperatorCard(tripDetail: tripDetail, l10n: l10n),
            const SizedBox(height: 12),
            _RouteTimelineCard(tripDetail: tripDetail),
            const SizedBox(height: 12),
            _AmenitiesSection(amenities: tripDetail.amenities, l10n: l10n),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Operator card ─────────────────────────────────────────────────────────────

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.tripDetail, required this.l10n});
  final BusTripDetail tripDetail;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final summary = tripDetail.summary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryTint,
            child: Text(
              summary.operatorCode,
              style: AppTypography.title.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.operatorName,
                    style: AppTypography.title
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(summary.serviceClass,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryTint,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.star, color: AppColors.secondary, size: 14),
                SizedBox(width: 4),
                Text(
                  '4.9',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.onSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route timeline ────────────────────────────────────────────────────────────

class _RouteTimelineCard extends StatelessWidget {
  const _RouteTimelineCard({required this.tripDetail});
  final BusTripDetail tripDetail;

  @override
  Widget build(BuildContext context) {
    final summary = tripDetail.summary;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: AppSpacing.cardPadding,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline indicator column
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.hairline,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            // Route info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StopInfo(
                    time: summary.departLabel,
                    terminal: tripDetail.terminalFrom,
                    sub: tripDetail.terminalFromSub,
                  ),
                  const SizedBox(height: 24),
                  _StopInfo(
                    time: summary.arriveLabel,
                    terminal: tripDetail.terminalTo,
                    sub: tripDetail.terminalToSub,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopInfo extends StatelessWidget {
  const _StopInfo(
      {required this.time, required this.terminal, required this.sub});
  final String time;
  final String terminal;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: AppTypography.h2),
        Text(terminal,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700)),
        Text(sub,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}

// ── Amenities ─────────────────────────────────────────────────────────────────

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.amenities, required this.l10n});
  final List<String> amenities;
  final AppLocalizations l10n;

  // Maps mock amenity strings to (icon, localized label) pairs.
  (IconData, String) _amenityInfo(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wi-fi':
        return (AppIcons.amenityWifi, l10n.amenityWifi);
      case 'a/c':
        return (AppIcons.amenityAC, l10n.amenityAC);
      case 'sockets':
        return (AppIcons.amenitySockets, l10n.amenitySockets);
      case 'water':
        return (AppIcons.amenityWater, l10n.amenityWater);
      default:
        return (AppIcons.check, amenity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tripDetailAmenities,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: amenities.map((a) {
              final (icon, label) = _amenityInfo(a);
              return AmenityChip(icon: icon, label: label);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Price footer ──────────────────────────────────────────────────────────────

class _PriceFooter extends StatelessWidget {
  const _PriceFooter({
    required this.priceEgp,
    required this.l10n,
    required this.onChooseSeats,
  });
  final int priceEgp;
  final AppLocalizations l10n;
  final VoidCallback onChooseSeats;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.tripDetailTotalPrice,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted)),
                Text(
                  '$priceEgp EGP',
                  style: AppTypography.h1.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.tripDetailChooseSeats,
              onPressed: onChooseSeats,
            ),
          ],
        ),
      ),
    );
  }
}
