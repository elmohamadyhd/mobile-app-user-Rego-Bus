import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_airport_labels.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_journeys.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_review.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/providers/flight_orders_provider.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_leg_badge.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_ticket_border.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/order_rate_trip_button.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';
import 'package:safaria/shared/widgets/order_review_sheet.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:safaria/shared/widgets/skyline_float_card.dart';

/// The flight-owned section dropped into the "My Tickets" tab shell
/// (`TicketsScreen`), mirroring `BusOrdersSection`'s guest/loading/error/
/// empty/list states.
class FlightOrdersSection extends ConsumerWidget {
  const FlightOrdersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestModeValue = ref.watch(guestModeProvider).value;
    if (guestModeValue == null) return const _OrdersSkeleton();
    if (guestModeValue) return const _GuestSignInCard();

    final ordersAsync = ref.watch(flightOrdersProvider);
    return ordersAsync.when(
      loading: () => const _OrdersSkeleton(),
      error: (error, _) =>
          _ErrorState(onRetry: () => ref.invalidate(flightOrdersProvider)),
      data: (orders) =>
          orders.isEmpty ? const _EmptyState() : _OrdersList(orders: orders),
    );
  }
}

class _GuestSignInCard extends StatelessWidget {
  const _GuestSignInCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.go(
            AppRoutes.login,
            extra: const AuthGateArgs(returnTo: AppRoutes.tickets),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsLight.user,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.profileGuestSignInCta,
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  PhosphorIconsLight.caretRight,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint,
              ),
              child: const Icon(
                PhosphorIconsLight.airplane,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.ticketsEmptyTitle,
              style: AppTypography.h1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.ticketsEmptyBody,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.ticketsBookCta,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SkylineFloatCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsLight.warningCircle,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.ticketsError,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(l10n.tripResultsRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.hairline,
      highlightColor: AppColors.bgElevated,
      child: Container(
        height: 160,
        decoration: const ShapeDecoration(
          color: AppColors.bgCard,
          shape: FlightTicketBorder(
            radius: AppRadius.card,
            notchRadius: 10,
            notchOffsetFromBottom: AppSpacing.lg,
            dashColor: AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({required this.orders});

  final List<FlightOrder> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(flightOrderAirportNamesProvider).value ?? const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final order in orders)
          _FlightOrderCard(order: order, airportNames: names),
      ],
    );
  }
}

class _FlightOrderCard extends ConsumerWidget {
  const _FlightOrderCard({
    required this.order,
    required this.airportNames,
  });

  final FlightOrder order;
  final Map<String, String> airportNames;

  static const double _cardActionHeight = 40;
  static const double _cardActionGap = AppSpacing.sm;
  static const double _notchRadius = 10;
  // Keeps the tear above the bottom edge when there are no actions so every
  // card shares the same boarding-pass silhouette.
  static const double _decorativeStubHeight = AppSpacing.lg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final paid = isFlightOrderPaid(order);
    final canRate = flightOrderCanRate(order);
    final rated = order.reviewRating;
    final journeys = groupFlightOrderJourneys(order.segments);
    final showPay = !paid;
    final checkoutUrl = order.checkoutUrl?.trim();
    final canPay = showPay && checkoutUrl != null && checkoutUrl.isNotEmpty;
    final showReview = canRate || rated != null;
    final actionsHeight = _actionsStubHeightFor(
      showPay: canPay,
      showReview: showReview,
    );
    final hasActions = actionsHeight > 0;
    final stubHeight = hasActions ? actionsHeight : _decorativeStubHeight;
    final shape = FlightTicketBorder(
      radius: AppRadius.card,
      notchRadius: _notchRadius,
      notchOffsetFromBottom: stubHeight,
      dashColor: AppColors.border,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.16),
            blurRadius: 32,
            spreadRadius: -14,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: AppColors.bgCard,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < journeys.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _OrderJourneyBlock(
                      hops: journeys[i],
                      index: i,
                      total: journeys.length,
                      airportNames: airportNames,
                      localeName: localeName,
                      trailing: i == 0 ? _StatusBadge(paid: paid) : null,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tripResultsFareLabel,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      LtrText(
                        '${order.totalAmount.toStringAsFixed(0)} ${order.currency}',
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: stubHeight,
              child: hasActions
                  ? Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (canPay)
                            PrimaryButton(
                              label: l10n.ticketActionPay,
                              compact: true,
                              onPressed: () =>
                                  context.push(FlightRoutes.pay, extra: order),
                            ),
                          if (canPay && showReview)
                            const SizedBox(height: _cardActionGap),
                          if (canRate)
                            OrderRateTripButton(
                              onPressed: () =>
                                  unawaited(_rate(context, ref, order)),
                            )
                          else if (rated != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: OrderRatedBadge(rating: rated),
                            ),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  static double _actionsStubHeightFor({
    required bool showPay,
    required bool showReview,
  }) {
    final actionCount = (showPay ? 1 : 0) + (showReview ? 1 : 0);
    if (actionCount == 0) return 0;

    var height = AppSpacing.xs + AppSpacing.sm;
    height += actionCount * _cardActionHeight;
    if (actionCount > 1) height += _cardActionGap;
    return height;
  }

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref,
    FlightOrder order,
  ) async {
    await showOrderReviewSheet(
      context,
      onSubmit: (rating, comment) async {
        await ref.read(flightRepositoryProvider).submitReview(
              orderId: order.id,
              rating: rating,
              comment: comment,
            );
        ref.invalidate(flightOrdersProvider);
      },
    );
  }
}

class _OrderJourneyBlock extends StatelessWidget {
  const _OrderJourneyBlock({
    required this.hops,
    required this.index,
    required this.total,
    required this.airportNames,
    required this.localeName,
    this.trailing,
  });

  final List<FlightOrderSegment> hops;
  final int index;
  final int total;
  final Map<String, String> airportNames;
  final String localeName;
  final Widget? trailing;

  static String _time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final first = hops.first;
    final last = hops.last;
    final origin = flightAirportDisplayName(
      iataCode: first.origin,
      namesByIata: airportNames,
    );
    final destination = flightAirportDisplayName(
      iataCode: last.destination,
      namesByIata: airportNames,
    );
    final badgeLabel = flightJourneyBadgeLabel(
      l10n,
      index: index,
      total: total,
    );
    final badgeKind = flightJourneyBadgeKind(index: index, total: total);
    final departure = first.departureDateTime;
    final arrival = last.arrivalDateTime;
    final stops = hops.length - 1;
    final stopsText = stops == 0
        ? l10n.flightDirect
        : stops == 1
            ? l10n.flightOneStop
            : l10n.flightStopsCount(stops);
    final flightNos = [
      for (final hop in hops)
        '${hop.marketingCarrierCode ?? ''}${hop.marketingFlightNumber ?? ''}',
    ].where((code) => code.trim().isNotEmpty).join(' · ');
    final flightMeta = flightNos.isEmpty ? '' : ' · $flightNos';
    final placeStyle = AppTypography.caption.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (badgeLabel != null && badgeKind != null)
              FlightLegBadge(label: badgeLabel, kind: badgeKind),
            if (departure != null) ...[
              if (badgeLabel != null) const SizedBox(width: AppSpacing.xs),
              FlightDateChip(DateFormat.MMMd(localeName).format(departure)),
            ],
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                origin,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: placeStyle,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(
                PhosphorIconsLight.caretRight,
                size: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: Text(
                destination,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: placeStyle,
              ),
            ),
          ],
        ),
        if (departure != null && arrival != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              LtrText(
                '${_time(departure)} – ${_time(arrival)}',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  '· $stopsText$flightMeta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = paid
        ? AppColors.success.withValues(alpha: 0.14)
        : AppColors.secondaryTint;
    final fg = paid ? AppColors.success : AppColors.onSecondary;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        paid ? l10n.ticketStatusConfirmed : l10n.ticketStatusPending,
        style: AppTypography.caption
            .copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}
