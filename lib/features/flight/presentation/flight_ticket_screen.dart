import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/domain/entities/flight_order.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_journeys.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_review.dart';
import 'package:safaria/features/flight/domain/utils/flight_order_status.dart';
import 'package:safaria/features/flight/presentation/flight_routes.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/providers/flight_orders_provider.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_fare_row.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_order_journey_block.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_order_status_badge.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_wizard_footer.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';
import 'package:safaria/shared/widgets/ltr_text.dart';
import 'package:safaria/shared/widgets/order_rate_trip_button.dart';
import 'package:safaria/shared/widgets/order_rated_badge.dart';
import 'package:safaria/shared/widgets/order_review_sheet.dart';

/// Ticket details — opened from My Tickets, and after a verified payment.
class FlightTicketScreen extends ConsumerWidget {
  const FlightTicketScreen({super.key, required this.order});

  final FlightOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final refreshed = ref.watch(flightOrderProvider(order.id));
    final detail = refreshed.when(
      data: (value) => value ?? order,
      loading: () => order,
      error: (_, __) => order,
    );
    final names = ref
            .watch(
              flightAirportNamesProvider(packedFlightAirportCodes([detail])),
            )
            .value ??
        const <String, String>{};
    final paid = isFlightOrderPaid(detail) && !isFlightOrderCancelled(detail);
    final canRate = flightOrderCanRate(detail);
    final rated = detail.reviewRating;
    final journeys = groupFlightOrderJourneys(detail.segments);
    final checkoutUrl = detail.checkoutUrl?.trim();
    final canPay = !paid &&
        !isFlightOrderCancelled(detail) &&
        checkoutUrl != null &&
        checkoutUrl.isNotEmpty;
    final canPop = _routeCanPop(context);
    final showGoToTickets = paid && !canPop;
    final showFooter = canPay || showGoToTickets;
    final airlinePnr = detail.airlinePnr?.trim();
    final gdsPnr = detail.gdsPnr?.trim();
    final passengers = detail.passengers;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: l10n.orderDetailTitle,
        onBack: () => _leaveTicket(context),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (paid) _ConfirmedBanner(title: l10n.flightTicketTitle),
                for (var i = 0; i < journeys.length; i++)
                  _SectionCard(
                    child: FlightOrderJourneyBlock(
                      hops: journeys[i],
                      index: i,
                      total: journeys.length,
                      airportNames: names,
                      localeName: localeName,
                      trailing:
                          i == 0 ? FlightOrderStatusBadge(order: detail) : null,
                    ),
                  ),
                if (passengers.isNotEmpty)
                  _SectionCard(
                    title: l10n.flightPayTravellers,
                    children: [
                      for (var i = 0; i < passengers.length; i++)
                        _TravellerTile(
                          passenger: passengers[i],
                          slot: _passengerSlot(
                            l10n,
                            passengers[i].passengerTypeCode,
                            _ordinalOf(passengers, i),
                          ),
                        ),
                    ],
                  ),
                if (_hasReference(airlinePnr, gdsPnr))
                  _SectionCard(
                    title: l10n.orderDetailReferenceSection,
                    children: [
                      if (airlinePnr != null && airlinePnr.isNotEmpty)
                        _InfoRow(
                          label: l10n.flightTicketPnr,
                          value: airlinePnr,
                        ),
                      if (gdsPnr != null &&
                          gdsPnr.isNotEmpty &&
                          gdsPnr != airlinePnr)
                        _InfoRow(
                          label: (airlinePnr == null || airlinePnr.isEmpty)
                              ? l10n.flightTicketPnr
                              : l10n.flightTicketGdsPnr,
                          value: gdsPnr,
                        ),
                    ],
                  ),
                _SectionCard(
                  title: l10n.orderDetailFareSection,
                  children: [
                    FlightFareRow(
                      label: l10n.flightPriceTotal,
                      amount: detail.totalAmount,
                      currency: detail.currency,
                    ),
                  ],
                ),
                if (canRate)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.md,
                    ),
                    child: OrderRateTripButton(
                      onPressed: () => unawaited(
                        _rate(context, ref, detail),
                      ),
                    ),
                  )
                else if (rated != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.md,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OrderRatedBadge(rating: rated),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: showFooter
          ? FlightWizardFooter(
              totalLabel: l10n.flightPriceTotal,
              totalText:
                  '${detail.totalAmount.toStringAsFixed(0)} ${detail.currency}',
              ctaLabel: canPay ? l10n.ticketActionPay : l10n.flightGoToTickets,
              onCta: canPay
                  ? () => context.push(FlightRoutes.pay, extra: detail)
                  : () => context.go(AppRoutes.tickets),
            )
          : null,
    );
  }

  static bool _hasReference(String? airlinePnr, String? gdsPnr) {
    final airline = airlinePnr != null && airlinePnr.isNotEmpty;
    final gds = gdsPnr != null && gdsPnr.isNotEmpty && gdsPnr != airlinePnr;
    return airline || gds;
  }

  static int _ordinalOf(List<FlightOrderPassenger> passengers, int index) {
    final code = passengers[index].passengerTypeCode.toUpperCase();
    var seen = 0;
    for (var i = 0; i <= index; i++) {
      if (passengers[i].passengerTypeCode.toUpperCase() == code) seen++;
    }
    return seen;
  }

  static String _passengerSlot(
    AppLocalizations l10n,
    String typeCode,
    int ordinal,
  ) {
    return switch (typeCode.toUpperCase()) {
      'ADT' => l10n.flightPassengerAdultN(ordinal),
      'CHD' => l10n.flightPassengerChildN(ordinal),
      'INF' => l10n.flightPassengerInfantN(ordinal),
      _ => typeCode,
    };
  }

  static Future<void> _rate(
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
        ref.invalidate(flightOrderProvider(order.id));
      },
    );
  }
}

bool _routeCanPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.canPop();
  return Navigator.maybeOf(context)?.canPop() ?? false;
}

void _leaveTicket(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.tickets);
    }
    return;
  }
  final navigator = Navigator.maybeOf(context);
  if (navigator != null && navigator.canPop()) {
    navigator.pop();
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      children: [
        const Center(
          child: LtrIcon(
            PhosphorIconsLight.checkCircle,
            size: 40,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    this.title,
    this.children = const [],
    this.child,
  });

  final String? title;
  final List<Widget> children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppTypography.title.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (child != null) child!,
          ...children,
        ],
      ),
    );
  }
}

class _TravellerTile extends StatelessWidget {
  const _TravellerTile({
    required this.passenger,
    required this.slot,
  });

  final FlightOrderPassenger passenger;
  final String slot;

  @override
  Widget build(BuildContext context) {
    final name = [
      passenger.firstName,
      passenger.lastName,
    ]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    final title = name.isEmpty ? slot : name;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const LtrIcon(
              PhosphorIconsLight.user,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LtrText(
                  title,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  slot,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LtrText(
              value,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
