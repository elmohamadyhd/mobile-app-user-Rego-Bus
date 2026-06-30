import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/booking/domain/entities/trip.dart';
import 'package:rego/features/booking/presentation/providers/booking_providers.dart';
import 'package:rego/features/booking/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/booking/presentation/widgets/trip_card.dart';
import 'package:rego/l10n/app_localizations.dart';

class TripResultsScreen extends ConsumerStatefulWidget {
  const TripResultsScreen({super.key});

  @override
  ConsumerState<TripResultsScreen> createState() => _TripResultsScreenState();
}

class _TripResultsScreenState extends ConsumerState<TripResultsScreen> {
  int _selectedSort = 0; // 0=Times, 1=Cheapest, 2=Seats — UI only

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(bookingFlowProvider);
    final from = state.searchFrom ?? 'Cairo';
    final to = state.searchTo ?? 'Alexandria';
    final title = '$from → $to';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: title,
        subtitle: l10n.homeOnePax,
        action: const _FilterButton(),
      ),
      body: _buildBody(context, l10n, state),
    );
  }

  Widget _buildBody(
      BuildContext context, AppLocalizations l10n, BookingFlowState state) {
    if (state.status == BookingFlowStatus.loadingTrips) {
      return const _LoadingSkeleton();
    }
    if (state.status == BookingFlowStatus.error) {
      return _ErrorView(
        message: l10n.tripResultsError,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () => ref.read(bookingFlowProvider.notifier).searchTrips(
              state.searchFrom ?? '',
              state.searchTo ?? '',
              toIsoDate(state.searchDate ?? DateTime.now()),
              isRoundTrip: state.isRoundTrip,
              returnDate: state.isRoundTrip && state.searchReturnDate != null
                  ? toIsoDate(state.searchReturnDate!)
                  : null,
              flightClass: state.flightClass,
            ),
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
            itemCount: state.trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => TripCard(
              trip: state.trips[i],
              onTap: () => _selectTrip(state.trips[i]),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTrip(TripSummary trip) async {
    await ref.read(bookingFlowProvider.notifier).selectTrip(trip);
    if (mounted) unawaited(context.push(AppRoutes.tripDetail));
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
            onTap: () {
              // TODO: implement sort logic when real trip data is available
              onSelect(i);
            },
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
    // TODO: replace with shimmer animation when shimmer package is added
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.bgBase,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 100, height: 12, color: AppColors.bgBase),
                      const SizedBox(height: 6),
                      Container(width: 60, height: 10, color: AppColors.bgBase),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                  width: double.infinity, height: 10, color: AppColors.bgBase),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 60, height: 20, color: AppColors.bgBase),
                  Container(
                    width: 70,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bgBase,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
