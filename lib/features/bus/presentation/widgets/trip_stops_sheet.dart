import 'package:flutter/material.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/domain/entities/bus_stop.dart';
import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/route_timeline.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Opens the boarding + drop-off picker for a results card.
///
/// Selection applies immediately via [onChanged] (no Apply button).
Future<void> showTripStopsSheet(
  BuildContext context, {
  required BusTripSummary trip,
  required BusStop initialFrom,
  required BusStop initialTo,
  required void Function({required BusStop from, required BusStop to})
      onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _TripStopsSheet(
        trip: trip,
        initialFrom: initialFrom,
        initialTo: initialTo,
        onChanged: onChanged,
      ),
    ),
  );
}

class _TripStopsSheet extends StatefulWidget {
  const _TripStopsSheet({
    required this.trip,
    required this.initialFrom,
    required this.initialTo,
    required this.onChanged,
  });

  final BusTripSummary trip;
  final BusStop initialFrom;
  final BusStop initialTo;
  final void Function({required BusStop from, required BusStop to}) onChanged;

  @override
  State<_TripStopsSheet> createState() => _TripStopsSheetState();
}

class _TripStopsSheetState extends State<_TripStopsSheet> {
  late BusStop _from;
  late BusStop _to;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
  }

  void _setFrom(BusStop stop) {
    setState(() => _from = stop);
    widget.onChanged(from: _from, to: _to);
  }

  void _setTo(BusStop stop) {
    setState(() => _to = stop);
    widget.onChanged(from: _from, to: _to);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.tripResultsStopsSheetTitle,
                style:
                    AppTypography.title.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: RouteTimeline(
                    boardingStops: widget.trip.boardingStops,
                    dropoffStops: widget.trip.dropoffStops,
                    selectedFrom: _from,
                    selectedTo: _to,
                    currency: widget.trip.currency,
                    onBoardSelected: _setFrom,
                    onDropoffSelected: _setTo,
                    showSectionTitle: false,
                    enableMapsLongPress: false,
                    embedded: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
