import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/features/car/domain/entities/car_place.dart';
import 'package:safaria/features/car/presentation/car_place_picker_args.dart';
import 'package:safaria/shared/widgets/map_place_picker_screen.dart';

class CarPlacePickerScreen extends ConsumerWidget {
  const CarPlacePickerScreen({
    super.key,
    required this.args,
    @visibleForTesting this.onPickedForTest,
  });

  final CarPlacePickerArgs args;
  final void Function(CarPlace place)? onPickedForTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MapPlacePickerScreen(
      args: args.toMapPlacePickerArgs(),
      onPickedForTest: onPickedForTest,
    );
  }
}
