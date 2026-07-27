import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/map_location.dart';
import 'package:safaria/features/car/domain/entities/car_order.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/presentation/providers/car_orders_provider.dart';
import 'package:safaria/features/car/presentation/widgets/car_order_card.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/open_location_in_google_maps.dart';

/// Opens the private-order detail sheet, seeded from [order] while
/// `GET /profile/private/orders/:id` refreshes in the background.
Future<void> showCarOrderDetailSheet(BuildContext context, CarOrder order) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => _CarOrderDetailSheet(seed: order),
  );
}

bool _hasLabel(String? value) => value != null && value.trim().isNotEmpty;

MapLocation _mapLocation(CarNamedLocation location) {
  final hasCoords = location.latitude != 0 || location.longitude != 0;
  return MapLocation(
    name: location.name,
    latitude: hasCoords ? location.latitude : null,
    longitude: hasCoords ? location.longitude : null,
  );
}

class _CarOrderDetailSheet extends ConsumerWidget {
  const _CarOrderDetailSheet({required this.seed});

  final CarOrder seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final order = ref.watch(carOrderDetailProvider(seed.id)).value ?? seed;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final trip = order.trip;
    final hasRoute = trip != null &&
        (_hasLabel(trip.fromLocation.name) || _hasLabel(trip.toLocation.name));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.orderDetailTitle,
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.hairline, height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderSection(order: order),
                    if (hasRoute) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _RouteSection(trip: trip as CarTripQuote, l10n: l10n),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _TripInfoSection(order: order, l10n: l10n),
                    if (trip != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _VehicleSection(vehicle: trip.vehicle, l10n: l10n),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _PriceSection(order: order, l10n: l10n),
                    if (_hasPaymentInfo(order)) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _PaymentSection(order: order, l10n: l10n),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _ReferenceSection(order: order, l10n: l10n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _hasPaymentInfo(CarOrder order) =>
      _hasLabel(order.paymentGateway) ||
      _hasLabel(order.transactionStatus) ||
      _hasLabel(order.paymentInvoiceId);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueLtr = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool valueLtr;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? AppTypography.title.copyWith(fontWeight: FontWeight.w800)
        : AppTypography.body.copyWith(fontWeight: FontWeight.w600);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: valueLtr
              ? Directionality(
                  textDirection: TextDirection.ltr,
                  child:
                      Text(value, style: valueStyle, textAlign: TextAlign.end),
                )
              : Text(value, style: valueStyle, textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.order});

  final CarOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final company = order.trip?.company;
    final name = (company?.name.trim().isNotEmpty ?? false)
        ? company!.name
        : l10n.carTicketSectionTitle;
    final logoUrl = company?.logoUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _CompanyMark(name: name, logoUrl: logoUrl),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CarOrderStatusBadge(statusKind: order.statusKind),
      ],
    );
  }
}

class _CompanyMark extends StatelessWidget {
  const _CompanyMark({required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: (logoUrl != null && logoUrl!.isNotEmpty)
          ? NetworkImage(logoUrl!)
          : null,
      child: (logoUrl == null || logoUrl!.isEmpty)
          ? Text(
              initial.toUpperCase(),
              style: AppTypography.title.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({required this.trip, required this.l10n});

  final CarTripQuote trip;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailRouteSection),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RouteStopSide(
                location: trip.fromLocation,
                alignEnd: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Transform.flip(
                flipX: isRtl,
                child: const Icon(
                  AppIcons.forward,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              child: _RouteStopSide(
                location: trip.toLocation,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteStopSide extends StatelessWidget {
  const _RouteStopSide({
    required this.location,
    required this.alignEnd,
  });

  final CarNamedLocation location;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final name = location.name.trim();
    final canOpenMaps = name.isNotEmpty;
    final crossAlign =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.end : TextAlign.start;

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: crossAlign,
          children: [
            if (name.isNotEmpty) ...[
              Text(
                name,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w700),
                textAlign: textAlign,
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Icon(
                AppIcons.locationTo,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );

    if (!canOpenMaps) return content;

    return InkWell(
      onTap: () => confirmAndOpenLocationInGoogleMaps(
        context,
        location: _mapLocation(location),
      ),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: content,
    );
  }
}

class _TripInfoSection extends StatelessWidget {
  const _TripInfoSection({required this.order, required this.l10n});

  final CarOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(_InfoRow(label: label, value: value!));
    }

    addRow(l10n.carOrderDetailDeparture, order.departureDate);
    addRow(l10n.carOrderDetailReturn, order.returnDate);
    addRow(
      l10n.carOrderDetailTripType,
      order.rounded ? l10n.carOrderDetailRoundTrip : l10n.carOrderDetailOneWay,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.carOrderDetailTripSection),
        ...rows,
      ],
    );
  }
}

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({required this.vehicle, required this.l10n});

  final CarVehicle vehicle;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      vehicle.name,
      if (_hasLabel(vehicle.model)) vehicle.model!,
      if (vehicle.year != null) '${vehicle.year}',
    ];
    final title = parts.where((p) => p.trim().isNotEmpty).join(' ');
    final gearLabel = vehicle.gearType?.toLowerCase();
    final gear = switch (gearLabel) {
      'automatic' => l10n.carGearAutomatic,
      'manual' => l10n.carGearManual,
      null => null,
      final other => other,
    };
    final bags = (vehicle.bigBagsCount != null ||
            vehicle.smallBagsCount != null)
        ? l10n.carBags(vehicle.bigBagsCount ?? 0, vehicle.smallBagsCount ?? 0)
        : null;

    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(_InfoRow(label: label, value: value!));
    }

    addRow(l10n.carOrderDetailVehicle, title);
    addRow(l10n.carOrderDetailCategory, vehicle.categoryName);
    if (vehicle.seatsNumber > 0) {
      addRow(l10n.carOrderDetailSeats, '${vehicle.seatsNumber}');
    }
    addRow(l10n.carOrderDetailBags, bags);
    addRow(l10n.carOrderDetailGear, gear);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.carOrderDetailVehicleSection),
        ...rows,
      ],
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.order, required this.l10n});

  final CarOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final amount = '${order.currency} ${order.price}'.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailFareSection),
        _InfoRow(
          label: l10n.confirmTotal,
          value: amount,
          valueLtr: true,
          emphasized: true,
        ),
      ],
    );
  }
}

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({required this.order, required this.l10n});

  final CarOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void addRow(String label, String? value) {
      if (!_hasLabel(value)) return;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(_InfoRow(label: label, value: value!, valueLtr: true));
    }

    addRow(l10n.orderDetailPaymentProvider, order.paymentGateway);
    addRow(l10n.orderDetailPaymentStatus, order.transactionStatus);
    addRow(l10n.orderDetailInvoiceId, order.paymentInvoiceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.paymentTitle),
        ...rows,
      ],
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection({required this.order, required this.l10n});

  final CarOrder order;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _InfoRow(
        label: l10n.carOrderDetailOrderId,
        value: order.orderId,
        valueLtr: true,
      ),
    ];
    final tripId = order.trip?.id;
    if (tripId != null && tripId > 0) {
      rows.add(const SizedBox(height: AppSpacing.xs));
      rows.add(
        _InfoRow(
          label: l10n.orderDetailTripId,
          value: '$tripId',
          valueLtr: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(l10n.orderDetailReferenceSection),
        ...rows,
      ],
    );
  }
}
