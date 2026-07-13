import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_trip.dart';
import 'package:rego/features/bus/domain/entities/bus_trip_filters.dart';
import 'package:rego/features/bus/domain/utils/apply_bus_trip_filters.dart';
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/active_filter_chips.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/features/bus/presentation/widgets/trip_card.dart';
import 'package:rego/features/bus/presentation/widgets/trip_filter_button.dart';
import 'package:rego/features/bus/presentation/widgets/trip_filter_sheet.dart';
import 'package:rego/l10n/app_localizations.dart';

class TripResultsScreen extends ConsumerStatefulWidget {
  const TripResultsScreen({super.key});

  @override
  ConsumerState<TripResultsScreen> createState() => _TripResultsScreenState();
}

class _TripResultsScreenState extends ConsumerState<TripResultsScreen> {
  String? _loadingTripId;
  BusTripFilters _filters = const BusTripFilters();

  /// Default ordering: earliest departure first.
  List<BusTripSummary> _byDepartureTime(List<BusTripSummary> trips) {
    final list = [...trips];
    list.sort((a, b) => a.departTime.compareTo(b.departTime));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(busBookingProvider);
    final from = state.searchFromLabel ?? 'Cairo';
    final to = state.searchToLabel ?? 'Alexandria';
    final title = '$from → $to';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: title,
        action: TripFilterButton(
          filters: _filters,
          onTap: () => _openFilterSheet(context, state.trips),
        ),
      ),
      body: _buildBody(context, l10n, state),
    );
  }

  Widget _buildBody(
      BuildContext context, AppLocalizations l10n, BusBookingState state) {
    if (state.status == BusBookingStatus.loadingTrips) {
      return const _LoadingSkeleton();
    }
    if (state.status == BusBookingStatus.error) {
      return _ErrorView(
        message: l10n.tripResultsError,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () {
          final params = state.searchParams;
          if (params != null) {
            ref.read(busBookingProvider.notifier).searchTrips(params);
          }
        },
      );
    }
    if (state.trips.isEmpty) {
      return Center(
        child: Text(
          l10n.tripResultsNoTrips,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    final filtered = applyBusTripFilters(state.trips, _filters);
    if (filtered.isEmpty) {
      return _FilteredEmptyView(
        message: l10n.tripResultsNoMatchingTrips,
        clearLabel: l10n.tripResultsClearFilters,
        onClear: () => setState(() => _filters = const BusTripFilters()),
      );
    }
    final trips = _byDepartureTime(filtered);
    return Column(
      children: [
        if (_filters.isActive)
          ActiveFilterChips(
            filters: _filters,
            onRemove: (chip) =>
                setState(() => _filters = _filters.removeChip(chip)),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) => TripCard(
              trip: trips[i],
              loading: _loadingTripId == trips[i].id,
              onTap: () => _selectTrip(trips[i]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTrip(BusTripSummary trip) async {
    // Only one trip can be "loading" at a time — a second tap while one is
    // in flight is ignored rather than racing the notifier's state.
    if (_loadingTripId != null) return;
    setState(() => _loadingTripId = trip.id);
    await ref.read(busBookingProvider.notifier).selectTrip(trip);
    if (!mounted) return;
    setState(() => _loadingTripId = null);
    unawaited(context.push(BusRoutes.detail));
  }

  Future<void> _openFilterSheet(
    BuildContext context,
    List<BusTripSummary> trips,
  ) async {
    final result = await showTripFilterSheet(
      context,
      initial: _filters,
      trips: trips,
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.hairline,
      highlightColor: AppColors.bgElevated,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _TripCardSkeleton(),
      ),
    );
  }
}

class _TripCardSkeleton extends StatelessWidget {
  const _TripCardSkeleton();

  static const _block = BoxDecoration(color: AppColors.hairline);

  static Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: _block,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      decoration: const ShapeDecoration(
        color: AppColors.bgElevated,
        shape: TicketBorder(
          radius: AppRadius.xl,
          notchRadius: 10,
          notchOffsetFromBottom: 64,
          dashColor: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.hairline,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(110, 13),
                        const SizedBox(height: 7),
                        _bar(64, 10),
                      ],
                    ),
                    const Spacer(),
                    _bar(66, 22),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _bar(52, 20),
                    _bar(70, 12),
                    _bar(52, 20),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _bar(72, 24),
                Container(
                  width: 92,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(AppRadius.input),
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

class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({
    required this.message,
    required this.clearLabel,
    required this.onClear,
  });

  final String message;
  final String clearLabel;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onClear, child: Text(clearLabel)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.error, color: AppColors.error, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
