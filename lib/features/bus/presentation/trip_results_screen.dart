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
import 'package:rego/features/bus/presentation/bus_routes.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/features/bus/presentation/widgets/trip_card.dart';
import 'package:rego/l10n/app_localizations.dart';

class TripResultsScreen extends ConsumerStatefulWidget {
  const TripResultsScreen({super.key});

  @override
  ConsumerState<TripResultsScreen> createState() => _TripResultsScreenState();
}

class _TripResultsScreenState extends ConsumerState<TripResultsScreen> {
  int _selectedSort = 0; // 0=Times, 1=Cheapest, 2=Seats
  String? _loadingTripId;

  /// Client-side reorder of already-loaded trips (no re-search).
  List<BusTripSummary> _sorted(List<BusTripSummary> trips) {
    final list = [...trips];
    switch (_selectedSort) {
      case 1: // Cheapest first
        list.sort((a, b) => a.priceEgp.compareTo(b.priceEgp));
      case 2: // Most seats first
        list.sort((a, b) => b.seatsLeft.compareTo(a.seatsLeft));
      case 0: // Earliest departure first
      default:
        list.sort((a, b) => a.departTime.compareTo(b.departTime));
    }
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
        action: const _FilterButton(),
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
    final trips = _sorted(state.trips);
    return Column(
      children: [
        _SortChips(
          selected: _selectedSort,
          onSelect: (i) => setState(() => _selectedSort = i),
          l10n: l10n,
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
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.tripResultsFilter,
      child: Center(
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.homeComingSoon)),
              ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child:
                  Icon(AppIcons.filter, color: AppColors.onPrimary, size: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChips extends StatelessWidget {
  const _SortChips({
    required this.selected,
    required this.onSelect,
    required this.l10n,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final labels = [
      l10n.tripResultsSortTimes,
      l10n.tripResultsSortCheapest,
      l10n.tripResultsSortSeats,
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                labels[i],
                style: AppTypography.caption.copyWith(
                  color: active ? AppColors.onPrimary : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
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
