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
import 'package:rego/features/bus/presentation/widgets/amenity_icon.dart';
import 'package:rego/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:rego/features/bus/presentation/widgets/stop_selector.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
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
      appBar: BookingAppBar(
        title: l10n.tripDetailTitle,
        subtitle: _routeLabel(state, fromStop, toStop),
      ),
      bottomNavigationBar: _PriceFooter(
        priceEgp: fare,
        currency: trip.currency,
        l10n: l10n,
        loading: isLoadingSeats,
        onChooseSeats: isLoadingSeats
            ? null
            : () => _onChooseSeats(context, ref),
      ),
      // Section order mirrors the approved bus-flow-redesign spec: trip
      // identity + route + amenities first (so the user confirms this is the
      // trip they picked), then the boarding/drop-off pickers.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TripTicketCard(
              trip: trip,
              fromStop: fromStop,
              toStop: toStop,
              fare: state.segmentFare,
              l10n: l10n,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: Text(
                l10n.tripDetailFareLiveHint,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AmenitiesSection(amenities: trip.amenities, l10n: l10n),
            const SizedBox(height: AppSpacing.lg),
            StopSelector(
              title: l10n.tripDetailBoardAt,
              stops: trip.boardingStops,
              selected: fromStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: stop, to: toStop),
            ),
            const SizedBox(height: AppSpacing.lg),
            StopSelector(
              title: l10n.tripDetailDropOffAt,
              stops: trip.dropoffStops,
              selected: toStop,
              onSelected: (stop) => ref
                  .read(busBookingProvider.notifier)
                  .setStops(from: fromStop, to: stop),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  /// `"$from → $to"` using the search labels carried over from results, or
  /// falling back to the selected stops' own city names — keeps the header
  /// context continuous with the results screen the user just came from.
  String? _routeLabel(
    BusBookingState state,
    BusStop fromStop,
    BusStop toStop,
  ) {
    final from = state.searchFromLabel ?? fromStop.cityName;
    final to = state.searchToLabel ?? toStop.cityName;
    if (from.isEmpty || to.isEmpty) return null;
    return '$from → $to';
  }

  Future<void> _onChooseSeats(BuildContext context, WidgetRef ref) async {
    await ref.read(busBookingProvider.notifier).loadSeats();
    if (context.mounted) unawaited(context.push(BusRoutes.seats));
  }
}

// ── Trip ticket card ────────────────────────────────────────────────────────

/// Boarding-pass styled summary of the selected trip: operator + amenities,
/// the route timeline for the currently chosen stop pair, and a live fare
/// stub below the tear line. Deliberately reuses [TicketBorder] so the shape
/// a user tapped on the results list carries through to this screen.
class _TripTicketCard extends StatelessWidget {
  const _TripTicketCard({
    required this.trip,
    required this.fromStop,
    required this.toStop,
    required this.fare,
    required this.l10n,
  });

  final BusTripSummary trip;
  final BusStop fromStop;
  final BusStop toStop;
  final double fare;
  final AppLocalizations l10n;

  static const double _stubHeight = 60;

  @override
  Widget build(BuildContext context) {
    final departLabel = _formatTime(fromStop.arrivalAt ?? trip.departTime);
    final arriveLabel = _formatTime(toStop.arrivalAt ?? trip.arriveTime);
    const shape = TicketBorder(
      radius: AppRadius.xl,
      notchRadius: 10,
      notchOffsetFromBottom: _stubHeight,
      dashColor: AppColors.border,
    );

    return Material(
      color: AppColors.bgElevated,
      shape: shape,
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OperatorAvatar(trip: trip, size: 46),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: trip.operatorName,
                                  style: AppTypography.title.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (trip.serviceClass.trim().isNotEmpty)
                                  TextSpan(
                                    text: '  ·  ${trip.serviceClass}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          AmenityIconsRow(amenities: trip.amenities),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _TicketTimeline(
                  departLabel: departLabel,
                  arriveLabel: arriveLabel,
                  fromStop: fromStop,
                  toStop: toStop,
                  durationLabel: trip.durationLabel,
                ),
              ],
            ),
          ),
          SizedBox(
            height: _stubHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                0,
              ),
              child: _LiveFareRow(fare: fare, currency: trip.currency, l10n: l10n),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TicketTimeline extends StatelessWidget {
  const _TicketTimeline({
    required this.departLabel,
    required this.arriveLabel,
    required this.fromStop,
    required this.toStop,
    required this.durationLabel,
  });

  final String departLabel;
  final String arriveLabel;
  final BusStop fromStop;
  final BusStop toStop;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
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
                SizedBox(
                  height: 30,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      durationLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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
    );
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

class _LiveFareRow extends StatelessWidget {
  const _LiveFareRow({
    required this.fare,
    required this.currency,
    required this.l10n,
  });

  final double fare;
  final String currency;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tripDetailFareLabel,
                style:
                    AppTypography.overline.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 1),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${fare.round()}',
                        style: AppTypography.h1.copyWith(
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
                  key: ValueKey(fare.round()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Icon(
          AppIcons.ticket,
          size: 30,
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ],
    );
  }
}

// ── Amenities ────────────────────────────────────────────────────────────────

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.amenities, required this.l10n});

  final List<String> amenities;
  final AppLocalizations l10n;

  String _amenityLabel(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wi-fi':
        return l10n.amenityWifi;
      case 'a/c':
        return l10n.amenityAC;
      case 'sockets':
        return l10n.amenitySockets;
      case 'water':
        return l10n.amenityWater;
      default:
        return amenity;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
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
              children: amenities
                  .map(
                    (a) => AmenityChip(
                      icon: amenityIconFor(a),
                      label: _amenityLabel(a),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

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
