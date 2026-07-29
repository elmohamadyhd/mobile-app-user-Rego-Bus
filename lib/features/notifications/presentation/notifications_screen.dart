import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/notifications/domain/entities/app_notification.dart';
import 'package:safaria/features/notifications/domain/entities/notifications_page.dart';
import 'package:safaria/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:safaria/features/notifications/presentation/widgets/notification_card.dart';
import 'package:safaria/features/notifications/presentation/widgets/notifications_app_bar.dart';
import 'package:safaria/features/notifications/presentation/widgets/notifications_section_header.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(notificationsProvider);
    final hasItems = async.value?.items.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: NotificationsAppBar(
        title: l10n.notificationsScreenTitle,
        action: hasItems
            ? TextButton(
                onPressed: () => _confirmClearAll(context, ref),
                child: Text(
                  l10n.notificationsClearAll,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.notificationsError,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).refresh(),
                child: Text(l10n.notificationsRetry),
              ),
            ],
          ),
        ),
        data: (page) => _NotificationsList(
          page: page,
          onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
          onLoadMore: () =>
              ref.read(notificationsProvider.notifier).loadMore(),
          onDelete: (id) => _deleteOne(context, ref, id),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notificationsClearAllConfirmTitle),
        content: Text(l10n.notificationsClearAllConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.notificationsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.notificationsClearAllConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(notificationsProvider.notifier).clearAll();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsClearFailed)),
      );
    }
  }

  Future<void> _deleteOne(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(notificationsProvider.notifier).delete(id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsDeleteFailed)),
      );
    }
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({
    required this.page,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onDelete,
  });

  final NotificationsPage page;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Future<void> Function(String id) onDelete;

  static const double _loadMoreThreshold = 200;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread =
        page.items.where((n) => n.isUnread).toList(growable: false);
    final read = page.items.where((n) => !n.isUnread).toList(growable: false);

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
                        ? const _EmptyState()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (unread.isNotEmpty) ...[
                                NotificationsSectionHeader(
                                  label: l10n.notificationsSectionNew,
                                ),
                                for (final n in unread)
                                  _DismissibleCard(
                                    key: ValueKey(n.id),
                                    notification: n,
                                    onDelete: onDelete,
                                  ),
                              ],
                              if (read.isNotEmpty) ...[
                                NotificationsSectionHeader(
                                  label: l10n.notificationsSectionEarlier,
                                ),
                                for (final n in read)
                                  _DismissibleCard(
                                    key: ValueKey(n.id),
                                    notification: n,
                                    onDelete: onDelete,
                                  ),
                              ],
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

class _DismissibleCard extends StatelessWidget {
  const _DismissibleCard({
    super.key,
    required this.notification,
    required this.onDelete,
  });

  final AppNotification notification;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Dismissible(
        key: ValueKey('dismiss-${notification.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: const Icon(
            PhosphorIconsLight.trash,
            color: AppColors.onPrimary,
          ),
        ),
        onDismissed: (_) => onDelete(notification.id),
        child: NotificationCard(notification: notification),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsLight.bellSlash,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.notificationsEmptyTitle,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.notificationsEmptySubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
