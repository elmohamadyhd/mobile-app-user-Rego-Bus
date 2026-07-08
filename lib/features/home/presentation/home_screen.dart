import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/features/auth/presentation/providers/auth_providers.dart';
import 'package:rego/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:rego/features/home/presentation/widgets/home_search_card.dart';
import 'package:rego/features/home/presentation/widgets/popular_destinations.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/shell_tab_scroll_view.dart';
import 'package:rego/shared/widgets/skyline_tab_hero.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _transportTab = 0;

  @override
  Widget build(BuildContext context) {
    // Load bus cities once when home opens so pickers are instant.
    ref.watch(busLocationsProvider);

    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionControllerProvider).value?.user;
    final userName = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!
        : l10n.homeMockUser;
    final initial = userName.isNotEmpty ? userName.substring(0, 1) : '?';

    return ShellTabScrollView(
      hero: SkylineTabHero(
        child: SkylineTabGreetingRow(
          initial: initial,
          greeting: l10n.homeGreeting(userName),
          headline: l10n.homeWhereTo,
          trailing: const SkylineTabHeroBellButton(),
        ),
      ),
      children: [
        HomeSearchCard(
          selectedTab: _transportTab,
          onTabChanged: (i) => setState(() => _transportTab = i),
        ),
        const PopularDestinations(),
      ],
    );
  }
}
