import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:rego/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';
import 'package:rego/shared/widgets/transport_mode_tab_bar.dart';

/// Composition root for the "My Tickets" bottom-nav tab. Owns only the hero
/// and scroll scaffold — each transport mode contributes its own section
/// widget (currently just [BusOrdersSection]; flight/car add their own later
/// with no refactor here).
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // `guestModeProvider` is async — `.value` is null while it resolves.
    // Only watch the protected `busOrdersProvider` once it's definitely
    // `false` (signed in), so a guest never triggers that fetch even
    // transiently, just to show a count in the hero.
    final guestModeValue = ref.watch(guestModeProvider).value;
    final count = guestModeValue == false
        ? ref.watch(busOrdersProvider).value?.length
        : null;

    return RefreshIndicator(
      onRefresh: guestModeValue == false
          ? () => ref.read(busOrdersProvider.notifier).refresh()
          : () async {},
      child: ShellTabScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        hero: SkylineTabHero(
          child: SkylineTabHeroText(
            headline: l10n.navTickets,
            caption: count != null ? l10n.ticketsCountLabel(count) : null,
          ),
        ),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59146CEC),
                  blurRadius: 40,
                  spreadRadius: -18,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TransportModeTabBar(
                  selectedIndex: TransportModeTabBar.busTabIndex,
                  onChanged: (i) {
                    if (i != TransportModeTabBar.busTabIndex) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(l10n.homeComingSoon),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                const BusOrdersSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
