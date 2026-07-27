import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

class CarConfirmScreen extends ConsumerStatefulWidget {
  const CarConfirmScreen({super.key});

  @override
  ConsumerState<CarConfirmScreen> createState() => _CarConfirmScreenState();
}

class _CarConfirmScreenState extends ConsumerState<CarConfirmScreen> {
  var _termsAccepted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(carBookingProvider);
    final quote = state.selectedQuote;
    final params = state.searchParams;
    final rounded = params?.rounded ?? quote?.rounded ?? false;
    final isCreating = state.status == CarBookingStatus.creatingOrder;

    ref.listen<CarBookingState>(carBookingProvider, (prev, next) {
      if (next.status == CarBookingStatus.awaitingPayment) {
        context.push(CarRoutes.pay);
      } else if (next.status == CarBookingStatus.confirmed) {
        context.go(CarRoutes.voucher);
      } else if (next.status == CarBookingStatus.error &&
          next.bookingError != null &&
          prev?.status == CarBookingStatus.creatingOrder) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                next.bookingError!.isEmpty
                    ? l10n.carConfirmCreateError
                    : next.bookingError!,
              ),
            ),
          );
      }
    });

    if (quote == null || params == null) {
      return Scaffold(
        backgroundColor: AppColors.bgBase,
        appBar: BookingAppBar(title: l10n.carConfirmTitle),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.carConfirmMissingTrip, style: AppTypography.body),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: l10n.carVoucherBackHome,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final price = quote.priceFor(rounded: rounded);
    final priceLabel =
        NumberFormat.currency(name: quote.currency, symbol: '${quote.currency} ')
            .format(price);
    final dateLabel = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(params.departDate);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: l10n.carConfirmTitle,
        subtitle: '${params.from.label} → ${params.to.label}',
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: l10n.carConfirmPay,
            loading: isCreating,
            onPressed: isCreating
                ? null
                : () {
                    if (!_termsAccepted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l10n.confirmTermsRequired)),
                        );
                      return;
                    }
                    ref.read(carBookingProvider.notifier).createOrder();
                  },
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryCard(
                    quote: quote,
                    routeLabel: '${params.from.label} → ${params.to.label}',
                    dateLabel: dateLabel,
                    priceLabel: priceLabel,
                    rounded: rounded,
                    l10n: l10n,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BookingTermsCheckbox(
                    value: _termsAccepted,
                    onChanged: (v) => setState(() => _termsAccepted = v),
                    onOpenTerms: () => context.push(CmsPagePaths.terms),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.quote,
    required this.routeLabel,
    required this.dateLabel,
    required this.priceLabel,
    required this.rounded,
    required this.l10n,
  });

  final CarTripQuote quote;
  final String routeLabel;
  final String dateLabel;
  final String priceLabel;
  final bool rounded;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(routeLabel, style: AppTypography.h2),
          const SizedBox(height: AppSpacing.sm),
          _row(AppIcons.calendar, dateLabel),
          if (rounded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.homeTripRoundTrip,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _row(
            AppIcons.transfer,
            '${quote.vehicle.categoryName} · ${quote.vehicle.name}',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            quote.company.name,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          if (quote.company.refundability) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.carRefundable,
              style: AppTypography.caption.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            priceLabel,
            style: AppTypography.h1.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.body)),
      ],
    );
  }
}
