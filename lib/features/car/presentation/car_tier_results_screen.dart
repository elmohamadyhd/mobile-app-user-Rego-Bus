import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_icons.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/auth/presentation/widgets/guest_gate_sheet.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/car/domain/entities/car_search_params.dart';
import 'package:safaria/features/car/presentation/car_routes.dart';
import 'package:safaria/features/car/presentation/providers/car_booking_providers.dart';
import 'package:safaria/features/car/presentation/widgets/car_tier_card.dart';
import 'package:safaria/l10n/app_localizations.dart';

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > AppBreakpoints.maxContentWidth
              ? AppBreakpoints.maxContentWidth
              : constraints.maxWidth;
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: _buildBody(context, l10n, state),
            ),
          );
        },
      ),
    );
  }

  String? _subtitle(BuildContext context, CarSearchParams? params) {
    if (params == null) return null;
    final locale = Localizations.localeOf(context).toString();
    final depart = formatSearchDateTimeCell(params.departDate, locale);
    if (params.rounded && params.returnDate != null) {
      final ret = formatSearchDateTimeCell(params.returnDate!, locale);
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
      return _EmptyView(
        title: l10n.carNoQuotes,
        body: l10n.carNoQuotesBody,
      );
    }

    final rounded = state.searchParams?.rounded ?? false;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        final params = state.searchParams;
        if (params != null) {
          await ref.read(carBookingProvider.notifier).searchQuotes(params);
        }
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: state.quotes.length + 1,
        separatorBuilder: (_, index) {
          if (index == 0) return const SizedBox(height: AppSpacing.md);
          return const SizedBox(height: AppSpacing.md);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ResultsHeader(
              title: l10n.carChooseVehicle,
              countLabel: l10n.carQuotesCount(state.quotes.length),
            );
          }
          final quote = state.quotes[index - 1];
          return CarTierCard(
            key: ValueKey(quote.id),
            quote: quote,
            rounded: rounded,
            onTap: () {
              ref.read(carBookingProvider.notifier).selectQuote(quote);
              context.push(CarRoutes.details);
            },
          );
        },
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.title,
    required this.countLabel,
  });

  final String title;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            countLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.bgBase,
        highlightColor: AppColors.bgElevated,
        child: Container(
          height: 188,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.transfer,
                color: AppColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.error,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}
