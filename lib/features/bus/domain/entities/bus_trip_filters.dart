import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rego/l10n/app_localizations.dart';

part 'bus_trip_filters.freezed.dart';

/// Identifies which constraint an active-filter chip represents.
enum ActiveFilterChipKind {
  operator,
  departAfter,
  departBefore,
  minPrice,
  maxPrice,
}

/// One removable chip shown on the results screen when a filter is active.
class ActiveFilterChip {
  const ActiveFilterChip({
    required this.kind,
    required this.label,
    this.operatorName,
  });

  final ActiveFilterChipKind kind;
  final String label;

  /// Set only when [kind] is [ActiveFilterChipKind.operator].
  final String? operatorName;
}

@freezed
abstract class BusTripFilters with _$BusTripFilters {
  const factory BusTripFilters({
    @Default(<String>{}) Set<String> operators,
    TimeOfDay? departAfter,
    TimeOfDay? departBefore,
    int? minPriceEgp,
    int? maxPriceEgp,
  }) = _BusTripFilters;

  const BusTripFilters._();

  bool get isActive =>
      operators.isNotEmpty ||
      departAfter != null ||
      departBefore != null ||
      minPriceEgp != null ||
      maxPriceEgp != null;

  /// Builds the list of active chips for display (one chip per constraint).
  List<ActiveFilterChip> activeChips(AppLocalizations l10n) {
    final chips = <ActiveFilterChip>[];
    for (final name in operators) {
      chips.add(
        ActiveFilterChip(
          kind: ActiveFilterChipKind.operator,
          label: name,
          operatorName: name,
        ),
      );
    }
    if (departAfter != null) {
      chips.add(
        ActiveFilterChip(
          kind: ActiveFilterChipKind.departAfter,
          label: l10n.tripFilterDepartAfter(
            _formatTime(departAfter!),
          ),
        ),
      );
    }
    if (departBefore != null) {
      chips.add(
        ActiveFilterChip(
          kind: ActiveFilterChipKind.departBefore,
          label: l10n.tripFilterDepartBefore(
            _formatTime(departBefore!),
          ),
        ),
      );
    }
    if (minPriceEgp != null) {
      chips.add(
        ActiveFilterChip(
          kind: ActiveFilterChipKind.minPrice,
          label: l10n.tripFilterPriceFrom(minPriceEgp!),
        ),
      );
    }
    if (maxPriceEgp != null) {
      chips.add(
        ActiveFilterChip(
          kind: ActiveFilterChipKind.maxPrice,
          label: l10n.tripFilterPriceUpTo(maxPriceEgp!),
        ),
      );
    }
    return chips;
  }

  /// Returns a copy with the constraint represented by [chip] removed.
  BusTripFilters removeChip(ActiveFilterChip chip) {
    return switch (chip.kind) {
      ActiveFilterChipKind.operator => copyWith(
          operators: {...operators}..remove(chip.operatorName),
        ),
      ActiveFilterChipKind.departAfter => copyWith(departAfter: null),
      ActiveFilterChipKind.departBefore => copyWith(departBefore: null),
      ActiveFilterChipKind.minPrice => copyWith(minPriceEgp: null),
      ActiveFilterChipKind.maxPrice => copyWith(maxPriceEgp: null),
    };
  }

  static String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
