import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_chip.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/stop_selector.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class BusTripDetailsScreen extends ConsumerWidget {
  const BusTripDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(busBookingProvider);
    final trip = state.selectedTrip;

    if (trip == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(title: l10n.tripDetailTitle),
        body: Center(
          child: Text(
            l10n.tripResultsNoTrips,
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final fromStop = state.fromStop ?? trip.defaultBoardingStop;
    final toStop = state.toStop ?? trip.defaultDropoffStop;
    final fare = state.segmentFare.round();
    final isLoadingSeats = state.status == BusBookingStatus.loadingSeats;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.tripDetailTitle),
      bottomNavigationBar: _PriceFooter(
        priceEgp: fare,
        currency: trip.currency,
        l10n: l10n,
        loading: isLoadingSeats,
        onChooseSeats: isLoadingSeats
            ? null
            : () => _onChooseSeats(context, ref),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StopSelector(
              title: l10n.homeFrom,
              stops: trip.boardingStops,
              selected: fromStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: stop, to: toStop),
            ),
            const SizedBox(height: AppSpacing.lg),
            StopSelector(
              title: l10n.homeTo,
              stops: trip.dropoffStops,
              selected: toStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: fromStop, to: stop),
            ),
            const SizedBox(height: AppSpacing.md),
            _SegmentFareBar(fare: state.segmentFare, currency: trip.currency),
            const SizedBox(height: AppSpacing.md),
            _OperatorCard(trip: trip, l10n: l10n),
            const SizedBox(height: 12),
            _RouteTimelineCard(
              trip: trip,
              fromStop: fromStop,
              toStop: toStop,
            ),
            const SizedBox(height: 12),
            _AmenitiesSection(amenities: trip.amenities, l10n: l10n),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _onChooseSeats(BuildContext context, WidgetRef ref) async {
    await ref.read(busBookingProvider.notifier).loadSeats();
    if (context.mounted) unawaited(context.push(BusRoutes.seats));
  }
}

class _SegmentFareBar extends StatelessWidget {
  const _SegmentFareBar({required this.fare, required this.currency});

  final double fare;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.tripDetailTotalPrice,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            '${fare.round()} $currency',
            style: AppTypography.h2.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _OperatorCard extends StatelessWidget {
  const _OperatorCard({required this.trip, required this.l10n});

  final BusTripSummary trip;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
            backgroundImage:
                trip.operatorLogoUrl != null
                    ? NetworkImage(trip.operatorLogoUrl!)
                    : null,
            child: trip.operatorLogoUrl == null
                ? Text(
                    trip.operatorCode,
                    style: AppTypography.title.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.operatorName,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  trip.serviceClass,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
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

class _RouteTimelineCard extends StatelessWidget {
  const _RouteTimelineCard({
    required this.trip,
    required this.fromStop,
    required this.toStop,
  });

  final BusTripSummary trip;
  final BusStop fromStop;
  final BusStop toStop;

  @override
  Widget build(BuildContext context) {
    final departLabel = _formatTime(fromStop.arrivalAt ?? trip.departTime);
    final arriveLabel = _formatTime(toStop.arrivalAt ?? trip.arriveTime);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StopInfo(
                    time: departLabel,
                    terminal: fromStop.name,
                    sub: fromStop.cityName,
                  ),
                  const SizedBox(height: 24),
                  _StopInfo(
                    time: arriveLabel,
                    terminal: toStop.name,
                    sub: toStop.cityName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _StopInfo extends StatelessWidget {
  const _StopInfo({
    required this.time,
    required this.terminal,
    required this.sub,
  });

  final String time;
  final String terminal;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: AppTypography.h2),
        Text(
          terminal,
          style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          sub,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.amenities, required this.l10n});

  final List<String> amenities;
  final AppLocalizations l10n;

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
          Text(
            l10n.tripDetailAmenities,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
          ),
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

class _PriceFooter extends StatelessWidget {
  const _PriceFooter({
    required this.priceEgp,
    required this.currency,
    required this.l10n,
    required this.onChooseSeats,
    this.loading = false,
  });

  final int priceEgp;
  final String currency;
  final AppLocalizations l10n;
  final VoidCallback? onChooseSeats;
  final bool loading;

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
                Text(
                  l10n.tripDetailTotalPrice,
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
                Text(
                  '$priceEgp $currency',
                  style: AppTypography.h1.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l10n.tripDetailChooseSeats,
              loading: loading,
              onPressed: onChooseSeats,
            ),
          ],
        ),
      ),
    );
  }
}
