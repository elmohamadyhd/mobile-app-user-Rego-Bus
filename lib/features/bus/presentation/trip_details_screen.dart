import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/bus_routes.dart';
import 'package:safaria/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_chip.dart';
import 'package:safaria/features/bus/presentation/widgets/amenity_icons_row.dart';
import 'package:safaria/features/bus/presentation/widgets/feature_label.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_step_bar.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:safaria/features/bus/presentation/widgets/route_timeline.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_details_coach.dart';
import 'package:safaria/features/bus/presentation/widgets/trip_route_map_fab.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:safaria/shared/widgets/route_arrow_label.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class BusTripDetailsScreen extends ConsumerStatefulWidget {
  const BusTripDetailsScreen({super.key});

  @override
  ConsumerState<BusTripDetailsScreen> createState() =>
      _BusTripDetailsScreenState();
}

class _BusTripDetailsScreenState extends ConsumerState<BusTripDetailsScreen> {
  final _firstBoardingRowKey = GlobalKey();
  final _dropOffRowKey = GlobalKey();
  final _mapButtonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
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

    return TripDetailsCoachHost(
      tripLoaded: true,
      firstBoardingRowKey: _firstBoardingRowKey,
      dropOffRowKey: _dropOffRowKey,
      mapButtonKey: _mapButtonKey,
      child: Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(
          title: l10n.tripDetailTitle,
          subtitleWidget: _routeSubtitle(state, fromStop, toStop),
          action: Builder(
            builder: (context) => IconButton(
              icon: const Icon(PhosphorIconsLight.question, color: AppColors.textPrimary),
              tooltip: l10n.tripDetailCoachReplay,
              onPressed: TripDetailsCoachScope.isShowingOf(context)
                  ? null
                  : TripDetailsCoachScope.replayOf(context),
            ),
          ),
        ),
        bottomNavigationBar: _PriceFooter(
          priceEgp: fare,
          currency: trip.currency,
          l10n: l10n,
          loading: isLoadingSeats,
          onChooseSeats:
              isLoadingSeats ? null : () => _onChooseSeats(context, ref),
        ),
        // The screen's one job is choosing stops: a compact identity header
        // confirms this is the right trip, then the route timeline (the
        // screen's focus) drives stop selection and the live fare.
        body: Column(
          children: [
            const BookingStepBar(current: BusBookingStep.route),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TripHeaderCard(
                        trip: trip, fromStop: fromStop, toStop: toStop),
                    const SizedBox(height: AppSpacing.lg),
                    RouteTimeline(
                      boardingStops: trip.boardingStops,
                      dropoffStops: trip.dropoffStops,
                      selectedFrom: fromStop,
                      selectedTo: toStop,
                      currency: trip.currency,
                      onBoardSelected: (stop) => ref
                          .read(busBookingProvider.notifier)
                          .setStops(from: stop, to: toStop),
                      onDropoffSelected: (stop) => ref
                          .read(busBookingProvider.notifier)
                          .setStops(from: fromStop, to: stop),
                      firstBoardingRowKey: _firstBoardingRowKey,
                      dropOffRowKey: _dropOffRowKey,
                      headerTrailing: TripRouteMapFab(
                        coachKey: _mapButtonKey,
                        boardingStops: trip.boardingStops,
                        dropoffStops: trip.dropoffStops,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Builder(
                      builder: (context) {
                        if (TripDetailsCoachActiveScope.of(context)) {
                          return const SizedBox.shrink();
                        }
                        return SizedBox(
                          width: double.infinity,
                          child: Text(
                            l10n.tripDetailFareLiveHint,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// From→to under the details title — widget form so RTL doesn't flip the arrow.
  Widget? _routeSubtitle(
    BusBookingState state,
    BusStop fromStop,
    BusStop toStop,
  ) {
    final from = state.searchFromLabel ?? fromStop.cityName;
    final to = state.searchToLabel ?? toStop.cityName;
    if (from.isEmpty || to.isEmpty) return null;
    return RouteArrowLabel(from: from, to: to);
  }

  Future<void> _onChooseSeats(BuildContext context, WidgetRef ref) async {
    await ref.read(busBookingProvider.notifier).loadSeats();
    if (context.mounted) unawaited(context.push(BusRoutes.seats));
  }
}

// ── Trip header card ────────────────────────────────────────────────────────

/// Compact operator identity + amenities + selected-journey time line.
/// Confirms this is the right trip without competing with the route
/// timeline below it for attention. Amenities are icons-only here; tapping
/// them opens a labeled sheet.
class _TripHeaderCard extends StatelessWidget {
  const _TripHeaderCard({
    required this.trip,
    required this.fromStop,
    required this.toStop,
  });

  final BusTripSummary trip;
  final BusStop fromStop;
  final BusStop toStop;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _durationLabel(DateTime depart, DateTime arrive) {
    final diff = arrive.difference(depart).inMinutes;
    final minutes = diff > 0 ? diff : 0;
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final departDt = fromStop.arrivalAt ?? trip.departTime;
    final arriveDt = toStop.arrivalAt ?? trip.arriveTime;

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OperatorAvatar(trip: trip),
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
                      if (trip.features.isNotEmpty)
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () => _showAmenitiesSheet(context, l10n),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AmenityIconsRow(features: trip.features),
                              const Icon(
                                PhosphorIconsLight.caretDown,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${_formatTime(departDt)} → ${_formatTime(arriveDt)} · '
              '${_durationLabel(departDt, arriveDt)}',
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAmenitiesSheet(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              children: trip.features
                  .map(
                    (f) => AmenityChip(
                      feature: f,
                      label: featureLabel(l10n, f),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: MediaQuery.of(sheetContext).padding.bottom),
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
                  style:
                      AppTypography.body.copyWith(color: AppColors.textMuted),
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
