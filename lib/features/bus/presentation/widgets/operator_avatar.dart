import 'package:flutter/material.dart';

import 'package:safaria/features/bus/domain/entities/bus_trip.dart';
import 'package:safaria/features/bus/presentation/widgets/operator_mark.dart';

/// Operator identity for trip search/details — thin wrapper over [OperatorMark]
/// so logo treatment stays identical across cards, tickets, and e-tickets.
class OperatorAvatar extends StatelessWidget {
  const OperatorAvatar({super.key, required this.trip, this.size = 48});

  final BusTripSummary trip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return OperatorMark(
      name: trip.operatorName,
      logoUrl: trip.operatorLogoUrl,
      size: size,
    );
  }
}
