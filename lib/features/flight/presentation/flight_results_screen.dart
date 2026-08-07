import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_offer_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

class FlightResultsScreen extends ConsumerWidget {
  const FlightResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(flightBookingProvider);
    final title =
        '${state.searchFromLabel ?? ''} → ${state.searchToLabel ?? ''}';

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: title),
      body: _buildBody(context, ref, l10n, state),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    FlightBookingState state,
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: state.offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) {
        final offer = state.offers[i];
        return FlightOfferCard(
          key: ValueKey(offer.offerId),
          offer: offer,
          originLabel: state.searchFromLabel,
          destinationLabel: state.searchToLabel,
          onTap: () => context.push(FlightRoutes.offerDetails, extra: offer),
        );
      },
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
