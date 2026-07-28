import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/car/domain/entities/car_trip_quote.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/pages/cms_page_paths.dart';
import 'package:safaria/shared/widgets/booking_terms_checkbox.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class CarTripDetailsScreen extends ConsumerStatefulWidget {
  const CarTripDetailsScreen({super.key});

  @override
  ConsumerState<CarTripDetailsScreen> createState() =>
      _CarTripDetailsScreenState();
}

class _CarTripDetailsScreenState extends ConsumerState<CarTripDetailsScreen> {
  var _didRequestRefresh = false;
  var _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRefresh());
  }

  void _maybeRefresh() {
    if (!mounted || _didRequestRefresh) return;
    final guestMode = ref.read(guestModeProvider).value;
    // Skip until known signed-in (false). Guest / unresolved → no fetch.
    if (guestMode != false) return;

    final quote = ref.read(carBookingProvider).selectedQuote;
    if (quote == null) return;

    _didRequestRefresh = true;
    ref.read(carBookingProvider.notifier).loadTripDetails(quote.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(carBookingProvider);
    final guestMode = ref.watch(guestModeProvider).value;
    final quote = state.selectedQuote;
    final rounded = state.searchParams?.rounded ?? quote?.rounded ?? false;

    ref.listen(guestModeProvider, (previous, next) {
      if (next.value == false) {
        _didRequestRefresh = false;
        _maybeRefresh();
      }
    });

    final subtitle = _routeLabel(state, quote);
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

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(
        title: l10n.carTripDetailsTitle,
        subtitle: subtitle,
      ),
      bottomNavigationBar: quote == null || state.tripDetailsHardError != null
          ? null
          : _PayFooter(
              l10n: l10n,
              termsAccepted: _termsAccepted,
              isCreating: isCreating,
              onTermsChanged: (v) => setState(() => _termsAccepted = v),
              onOpenTerms: () => context.push(CmsPagePaths.terms),
              onPay: () => _onPayNow(context, guestMode),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > AppBreakpoints.maxContentWidth
              ? AppBreakpoints.maxContentWidth
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: _buildBody(context, l10n, state, quote, rounded),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CarBookingState state,
    CarTripQuote? quote,
    bool rounded,
  ) {
    if (quote == null) {
      return _EmptyBody(
        message: l10n.carTripDetailsMissing,
        onBack: () => context.pop(),
      );
    }

    if (state.tripDetailsHardError != null) {
      return _HardErrorBody(
        message: l10n.carTripDetailsNotFound,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () =>
            ref.read(carBookingProvider.notifier).loadTripDetails(quote.id),
        onBack: () => context.pop(),
      );
    }

    return Column(
      children: [
        if (state.isLoadingTripDetails)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.tripDetailsSoftError != null) ...[
                  _SoftErrorBanner(message: l10n.carTripDetailsRefreshFailed),
                  const SizedBox(height: AppSpacing.md),
                ],
                _ExpandedQuoteCard(
                  quote: quote,
                  rounded: rounded,
                  pickupLabel: state.searchParams?.from.label,
                  dropoffLabel: state.searchParams?.to.label,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _routeLabel(CarBookingState state, CarTripQuote? quote) {
    final params = state.searchParams;
    if (params != null) {
      return '${params.from.label} → ${params.to.label}';
    }
    if (quote == null) return null;
    return '${quote.fromLocation.name} → ${quote.toLocation.name}';
  }

  void _onPayNow(BuildContext context, bool? guestMode) {
    final l10n = AppLocalizations.of(context);
    if (guestMode != false) {
      showGuestGate(
        context,
        returnTo: CarRoutes.details,
        body: l10n.guestGateCarBody,
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.confirmTermsRequired)));
      return;
    }

    ref.read(carBookingProvider.notifier).createOrder();
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onBack, child: const Icon(PhosphorIconsLight.caretLeft)),
          ],
        ),
      ),
    );
  }
}

class _HardErrorBody extends StatelessWidget {
  const _HardErrorBody({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: retryLabel, onPressed: onRetry),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onBack, child: const Icon(PhosphorIconsLight.caretLeft)),
          ],
        ),
      ),
    );
  }
}

class _SoftErrorBanner extends StatelessWidget {
  const _SoftErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(PhosphorIconsLight.warningCircle, color: AppColors.warning, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedQuoteCard extends StatelessWidget {
  const _ExpandedQuoteCard({
    required this.quote,
    required this.rounded,
    this.pickupLabel,
    this.dropoffLabel,
  });

  final CarTripQuote quote;
  final bool rounded;
  final String? pickupLabel;
  final String? dropoffLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final price = quote.priceFor(rounded: rounded);
    final priceText = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).format(price);
    final pickup = (pickupLabel != null && pickupLabel!.isNotEmpty)
        ? pickupLabel!
        : quote.fromLocation.name;
    final dropoff = (dropoffLabel != null && dropoffLabel!.isNotEmpty)
        ? dropoffLabel!
        : quote.toLocation.name;

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _VehicleHero(quote: quote),
            const SizedBox(height: AppSpacing.md),
            Text(
              _vehicleTitle(quote),
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CompanyRow(company: quote.company),
            if (quote.company.refundability) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _RefundableBadge(label: l10n.carRefundable),
              ),
            ],
            if (quote.company.refundPolicy != null &&
                quote.company.refundPolicy!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                quote.company.refundPolicy!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _SpecChip(
                  icon: PhosphorIconsLight.users,
                  label: l10n.carSeats(quote.vehicle.seatsNumber),
                ),
                _SpecChip(
                  icon: PhosphorIconsLight.briefcase,
                  label: l10n.carBags(
                    quote.vehicle.bigBagsCount ?? 0,
                    quote.vehicle.smallBagsCount ?? 0,
                  ),
                ),
                _SpecChip(
                  icon: PhosphorIconsLight.steeringWheel,
                  label: _gearLabel(l10n, quote.vehicle.gearType),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.hairline),
            const SizedBox(height: AppSpacing.md),
            _RouteBlock(
              pickupTitle: l10n.carPickup,
              pickupValue: pickup,
              dropoffTitle: l10n.carDropoff,
              dropoffValue: dropoff,
            ),
            const SizedBox(height: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: priceText,
                    style: AppTypography.h2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: quote.currency,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _vehicleTitle(CarTripQuote quote) {
    final parts = <String>[quote.vehicle.categoryName];
    final name = quote.vehicle.name;
    if (name.isNotEmpty) parts.add(name);
    final model = quote.vehicle.model;
    if (model != null && model.isNotEmpty) parts.add(model);
    final year = quote.vehicle.year;
    if (year != null) parts.add('$year');
    return parts.join(' · ');
  }

  String _gearLabel(AppLocalizations l10n, String? gearType) {
    if (gearType == 'manual') return l10n.carGearManual;
    return l10n.carGearAutomatic;
  }
}

class _VehicleHero extends StatelessWidget {
  const _VehicleHero({required this.quote});

  final CarTripQuote quote;

  static const double _height = 180;

  @override
  Widget build(BuildContext context) {
    final url = quote.vehicle.featuredUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [AppColors.primaryTint, AppColors.inputFill],
            ),
          ),
          child: url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    PhosphorIconsLight.car,
                    color: AppColors.primary,
                    size: 48,
                  ),
                )
              : const Icon(
                  PhosphorIconsLight.car,
                  color: AppColors.primary,
                  size: 48,
                ),
        ),
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.company});

  final CarCompany company;

  @override
  Widget build(BuildContext context) {
    final logoUrl = company.logoUrl;
    return Row(
      children: [
        if (logoUrl != null && logoUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              logoUrl,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            company.name,
            style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({
    required this.pickupTitle,
    required this.pickupValue,
    required this.dropoffTitle,
    required this.dropoffValue,
  });

  final String pickupTitle;
  final String pickupValue;
  final String dropoffTitle;
  final String dropoffValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pickupTitle,
          style: AppTypography.overline.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          pickupValue,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          dropoffTitle,
          style: AppTypography.overline.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          dropoffValue,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RefundableBadge extends StatelessWidget {
  const _RefundableBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayFooter extends StatelessWidget {
  const _PayFooter({
    required this.l10n,
    required this.termsAccepted,
    required this.isCreating,
    required this.onTermsChanged,
    required this.onOpenTerms,
    required this.onPay,
  });

  final AppLocalizations l10n;
  final bool termsAccepted;
  final bool isCreating;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookingTermsCheckbox(
              value: termsAccepted,
              onChanged: onTermsChanged,
              onOpenTerms: onOpenTerms,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: l10n.carConfirmPay,
              loading: isCreating,
              onPressed: isCreating ? null : onPay,
            ),
          ],
        ),
      ),
    );
  }
}
