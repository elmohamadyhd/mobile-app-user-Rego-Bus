import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer.dart';
import 'package:safaria/features/flight/domain/entities/flight_offer_filters.dart';
import 'package:safaria/features/flight/domain/utils/apply_flight_offer_filters.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_filter_button.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_filter_sheet.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_offer_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class FlightResultsScreen extends ConsumerStatefulWidget {
  const FlightResultsScreen({super.key});

  @override
  ConsumerState<FlightResultsScreen> createState() =>
      _FlightResultsScreenState();
}

class _FlightResultsScreenState extends ConsumerState<FlightResultsScreen> {
  /// Offers rendered per batch. The search endpoint returns 600+ results with
  /// no server paging, so the window is entirely ours.
  static const _pageSize = 20;
  int _visible = _pageSize;

  Future<void> _openFilters() async {
    final state = ref.read(flightBookingProvider);
    final params = state.searchParams;
    if (params == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgElevated,
      builder: (sheetContext) => FlightFilterSheet(
        initial: state.filters,
        carriers: flightCarrierOptions(state.offers),
        priceBounds: flightPriceBounds(state.offers),
        initialDirectOnly: params.directFlightsOnly,
        matchCount: (filters) =>
            applyFlightOfferFilters(state.offers, filters).length,
        onApply: (filters, {required directOnly, required needsSearch}) {
          Navigator.of(sheetContext).pop();
          final notifier = ref.read(flightBookingProvider.notifier);
          notifier.setFilters(filters);
          if (needsSearch) {
            notifier.search(
              params.copyWith(directFlightsOnly: directOnly),
              preserveFilters: true,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final offers = ref.watch(flightFilteredOffersProvider);
    final title =
        '${state.searchFromLabel ?? ''} → ${state.searchToLabel ?? ''}';

    // A fresh result set restarts the window; without this, a re-search
    // inherits the previous scroll depth and renders far more than needed.
    ref.listen(
      flightBookingProvider.select((s) => s.offers),
      (_, __) => setState(() => _visible = _pageSize),
    );

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: title,
        action: FlightFilterButton(
          activeCount: state.filters.activeCount,
          onTap: _openFilters,
        ),
      ),
      body: _buildBody(l10n, state, offers),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    FlightBookingState state,
    List<FlightOffer> offers,
  ) {
    if (state.status == FlightBookingStatus.searching) {
      return const _LoadingSkeleton();
    }
    if (state.status == FlightBookingStatus.error) {
      return _ErrorView(
        message: l10n.tripResultsError,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () {
          final params = state.searchParams;
          if (params != null) {
            ref.read(flightBookingProvider.notifier).search(params);
          }
        },
      );
    }
    if (state.offers.isEmpty) {
      return Center(
        child: Text(
          l10n.flightResultsNoOffers,
          style: AppTypography.body.copyWith(color: AppColors.textMuted),
        ),
      );
    }
    if (offers.isEmpty && state.offers.isNotEmpty) {
      return _FilteredEmptyView(
        onClear: () => ref
            .read(flightBookingProvider.notifier)
            .setFilters(const FlightOfferFilters()),
      );
    }

    final windowed = offers.length < _visible ? offers.length : _visible;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400 &&
            _visible < offers.length) {
          setState(() => _visible += _pageSize);
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: windowed,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final offer = offers[i];
          return FlightOfferCard(
            key: ValueKey(offer.offerId),
            offer: offer,
            originLabel: state.searchFromLabel,
            destinationLabel: state.searchToLabel,
            onSelect: () {
              ref.read(flightBookingProvider.notifier).selectOffer(offer);
              context.push(FlightRoutes.review);
            },
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
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, __) => Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
          const Icon(
            PhosphorIconsLight.warningCircle,
            color: AppColors.error,
            size: 48,
          ),
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

/// Shown when local filters exclude every offer. The action is to clear the
/// filters, not to search again — the results are still there, we are hiding
/// them.
class _FilteredEmptyView extends StatelessWidget {
  const _FilteredEmptyView({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsLight.funnelX,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.flightFilterNoMatches,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.flightFilterClear,
              variant: PrimaryButtonVariant.ghost,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
