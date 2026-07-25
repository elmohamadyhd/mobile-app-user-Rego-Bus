import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/addresses/domain/entities/address_page.dart';
import 'package:safaria/features/addresses/presentation/addresses_routes.dart';
import 'package:safaria/features/addresses/presentation/providers/addresses_providers.dart';
import 'package:safaria/features/addresses/presentation/widgets/add_address_button.dart';
import 'package:safaria/features/addresses/presentation/widgets/address_card.dart';
import 'package:safaria/features/addresses/presentation/widgets/addresses_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AddressesAppBar(title: l10n.addressesScreenTitle),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.addressesError,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    ref.read(addressesProvider.notifier).refresh(),
                child: Text(l10n.addressesRetry),
              ),
            ],
          ),
        ),
        data: (page) => _AddressesList(
          page: page,
          onRefresh: () => ref.read(addressesProvider.notifier).refresh(),
          onLoadMore: () => ref.read(addressesProvider.notifier).loadMore(),
          onAdd: () => context.push(AddressesRoutes.create),
          onEdit: (id) => context.push(AddressesRoutes.edit(id)),
        ),
      ),
    );
  }
}

class _AddressesList extends StatelessWidget {
  const _AddressesList({
    required this.page,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onAdd,
    required this.onEdit,
  });

  final AddressPage page;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onAdd;
  final void Function(int id) onEdit;

  static const double _loadMoreThreshold = 200;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - _loadMoreThreshold) {
            onLoadMore();
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = context.isExpanded
                ? AppBreakpoints.maxContentWidth
                : constraints.maxWidth;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: page.items.isEmpty
                        ? _EmptyState(onAdd: onAdd)
                        : Column(
                            children: [
                              for (var i = 0; i < page.items.length; i++)
                                AddressCard(
                                  key: ValueKey(page.items[i].id),
                                  address: page.items[i],
                                  iconTintIndex: i,
                                  onTap: () => onEdit(page.items[i].id),
                                  onEdit: () => onEdit(page.items[i].id),
                                ),
                              const SizedBox(height: AppSpacing.md),
                              AddAddressButton(onTap: onAdd),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            l10n.addressesEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.addressesEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AddAddressButton(onTap: onAdd),
        ],
      ),
    );
  }
}
