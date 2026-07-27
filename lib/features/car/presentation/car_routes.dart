import 'package:go_router/go_router.dart';

import 'package:safaria/features/car/presentation/car_confirm_screen.dart';
import 'package:safaria/features/car/presentation/car_payment_pending_screen.dart';
import 'package:safaria/features/car/presentation/car_payment_webview_screen.dart';
import 'package:safaria/features/car/presentation/car_place_picker_args.dart';
import 'package:safaria/features/car/presentation/car_place_picker_screen.dart';
import 'package:safaria/features/car/presentation/car_tier_results_screen.dart';
import 'package:safaria/features/car/presentation/car_trip_details_screen.dart';
import 'package:safaria/features/car/presentation/car_voucher_screen.dart';

abstract final class CarRoutes {
  static const results = '/car/results';
  static const placePicker = '/car/place-picker';
  static const details = '/car/details';
  static const confirm = '/car/confirm';
  static const pay = '/car/pay';
  static const pending = '/car/pending';
  static const voucher = '/car/voucher';
}

List<RouteBase> carRoutes() => [
      GoRoute(
        path: CarRoutes.results,
        builder: (context, state) => const CarTierResultsScreen(),
      ),
      GoRoute(
        path: CarRoutes.details,
        builder: (context, state) => const CarTripDetailsScreen(),
      ),
      GoRoute(
        path: CarRoutes.confirm,
        builder: (context, state) => const CarConfirmScreen(),
      ),
      GoRoute(
        path: CarRoutes.pay,
        builder: (context, state) {
          final extra = state.extra;
          return CarPaymentWebViewScreen(
            args: extra is CarPaymentFlowArgs ? extra : null,
          );
        },
      ),
      GoRoute(
        path: CarRoutes.pending,
        builder: (context, state) => const CarPaymentPendingScreen(),
      ),
      GoRoute(
        path: CarRoutes.voucher,
        builder: (context, state) => const CarVoucherScreen(),
      ),
      GoRoute(
        path: CarRoutes.placePicker,
        builder: (context, state) {
          final args = state.extra;
          if (args is! CarPlacePickerArgs) {
            return const CarPlacePickerScreen(
              args: CarPlacePickerArgs(title: ''),
            );
          }
          return CarPlacePickerScreen(args: args);
        },
      ),
    ];
