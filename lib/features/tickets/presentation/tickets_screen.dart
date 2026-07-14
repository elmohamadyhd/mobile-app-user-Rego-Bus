import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';

/// Composition root for the "My Tickets" bottom-nav tab. Owns only the hero
/// and scroll scaffold — each transport mode contributes its own section
/// widget (currently just [BusOrdersSection]; flight/car add their own later
/// with no refactor here).
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    // Guarded: guests never trigger the protected `busOrdersProvider` fetch,
    // even just to show a count in the hero.
    final count = isGuest ? null : ref.watch(busOrdersProvider).value?.length;

    return RefreshIndicator(
      onRefresh: isGuest
          ? () async {}
          : () => ref.read(busOrdersProvider.notifier).refresh(),
      child: ShellTabScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        hero: SkylineTabHero(
          child: SkylineTabHeroText(
            headline: l10n.navTickets,
            caption: count != null ? l10n.ticketsCountLabel(count) : null,
          ),
        ),
        children: const [BusOrdersSection()],
      ),
    );
  }
}
