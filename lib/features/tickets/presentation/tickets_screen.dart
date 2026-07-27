import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/bus/presentation/providers/bus_orders_provider.dart';
import 'package:safaria/features/bus/presentation/widgets/bus_orders_section.dart';
import 'package:safaria/features/car/presentation/providers/car_orders_provider.dart';
import 'package:safaria/features/car/presentation/widgets/car_orders_section.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/shell_tab_scroll_view.dart';
import 'package:safaria/shared/widgets/skyline_tab_hero.dart';
import 'package:safaria/shared/widgets/transport_mode_tab_bar.dart';

/// Composition root for the "My Tickets" bottom-nav tab. Owns only the hero
/// and scroll scaffold — each transport mode contributes its own section.
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  var _modeIndex = TransportModeTabBar.busTabIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final guestModeValue = ref.watch(guestModeProvider).value;
    final busCount = guestModeValue == false
        ? ref.watch(busOrdersProvider).value?.length
        : null;
    final carCount = guestModeValue == false
        ? ref.watch(carOrdersProvider).value?.length
        : null;
    final count = _modeIndex == TransportModeTabBar.privateTabIndex
        ? carCount
        : busCount;

    return RefreshIndicator(
      onRefresh: guestModeValue == false
          ? () async {
              await Future.wait([
                ref.read(busOrdersProvider.notifier).refresh(),
                ref.read(carOrdersProvider.notifier).refresh(),
              ]);
            }
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
                  selectedIndex: _modeIndex,
                  onChanged: (i) {
                    if (i == TransportModeTabBar.flightTabIndex) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: Text(l10n.homeComingSoon),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      return;
                    }
                    setState(() => _modeIndex = i);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (_modeIndex == TransportModeTabBar.privateTabIndex)
                  const CarOrdersSection()
                else
                  const BusOrdersSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
