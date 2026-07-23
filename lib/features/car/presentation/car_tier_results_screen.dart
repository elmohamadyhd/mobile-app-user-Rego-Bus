import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/date_formatting.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:rego/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:rego/features/car/domain/entities/car_search_params.dart';
import 'package:rego/features/car/presentation/car_routes.dart';
import 'package:rego/features/car/presentation/providers/car_booking_providers.dart';
import 'package:rego/features/car/presentation/widgets/car_tier_card.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class CarTierResultsScreen extends ConsumerStatefulWidget {
  const CarTierResultsScreen({super.key});

  @override
  ConsumerState<CarTierResultsScreen> createState() =>
      _CarTierResultsScreenState();
}

class _CarTierResultsScreenState extends ConsumerState<CarTierResultsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuthRetry());
  }

  void _handleAuthRetry() {
    final state = ref.read(carBookingProvider);
    if (!state.needsAuthRetry || !mounted) return;

    final l10n = AppLocalizations.of(context);
    showGuestGate(
      context,
      returnTo: CarRoutes.results,
      body: l10n.guestGateCarBody,
    ).then((_) {
      if (!mounted) return;
      ref.read(carBookingProvider.notifier).clearAuthRetry();
      final params = ref.read(carBookingProvider).searchParams;
      if (params != null) {
        ref.read(carBookingProvider.notifier).searchQuotes(params);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CarBookingState>(carBookingProvider, (previous, next) {
      if (next.needsAuthRetry && previous?.needsAuthRetry != true) {
        _handleAuthRetry();
      }
    });

    final l10n = AppLocalizations.of(context);
    final state = ref.watch(carBookingProvider);
    final params = state.searchParams;
    final from = params?.from.label ?? '';
    final to = params?.to.label ?? '';
    final title = '$from → $to';
    final subtitle = _subtitle(context, params);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: title, subtitle: subtitle),
      body: _buildBody(context, l10n, state),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            label: l10n.carContinue,
            onPressed: state.selectedQuote == null ? null : () => _onContinue(),
          ),
        ),
      ),
    );
  }

  String? _subtitle(BuildContext context, CarSearchParams? params) {
    if (params == null) return null;
    final locale = Localizations.localeOf(context).toString();
    final depart = formatSearchDateCell(params.departDate, locale);
    if (params.rounded && params.returnDate != null) {
      final ret = formatSearchDateCell(params.returnDate!, locale);
      return '$depart · $ret';
    }
    return depart;
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CarBookingState state,
  ) {
    if (state.isLoadingQuotes) {
      return const _LoadingSkeleton();
    }
    if (state.quotesError != null && state.quotes.isEmpty) {
      return _ErrorView(
        message: state.quotesError!,
        retryLabel: l10n.tripResultsRetry,
        onRetry: () {
          final params = state.searchParams;
          if (params != null) {
            ref.read(carBookingProvider.notifier).searchQuotes(params);
          }
        },
      );
    }
    if (state.quotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.carNoQuotes,
                textAlign: TextAlign.center,
                style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.carNoQuotesBody,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final rounded = state.searchParams?.rounded ?? false;
    return RefreshIndicator(
      onRefresh: () async {
        final params = state.searchParams;
        if (params != null) {
          await ref.read(carBookingProvider.notifier).searchQuotes(params);
        }
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.quotes.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final quote = state.quotes[index];
          final selected = state.selectedQuote?.id == quote.id;
          return CarTierCard(
            quote: quote,
            rounded: rounded,
            selected: selected,
            onTap: () =>
                ref.read(carBookingProvider.notifier).selectQuote(quote),
          );
        },
      ),
    );
  }

  Future<void> _onContinue() async {
    final l10n = AppLocalizations.of(context);
    final isGuest = ref.read(guestModeProvider).value ?? false;
    if (isGuest) {
      await showGuestGate(
        context,
        returnTo: CarRoutes.results,
        body: l10n.guestGateCarBody,
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.carBookingComingSoon),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.bgBase,
        highlightColor: AppColors.bgElevated,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

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
              textAlign: TextAlign.center,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
