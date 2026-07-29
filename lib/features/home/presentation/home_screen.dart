import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/router/app_router.dart';
import 'package:safaria/features/auth/presentation/auth_flow_args.dart';
import 'package:safaria/features/auth/presentation/providers/auth_providers.dart';
import 'package:safaria/features/bus/presentation/providers/bus_locations_provider.dart';
import 'package:safaria/features/home/presentation/widgets/home_search_card.dart';
import 'package:safaria/features/home/presentation/widgets/popular_destinations.dart';
import 'package:safaria/features/notifications/presentation/notifications_routes.dart';
import 'package:safaria/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/shell_tab_scroll_view.dart';
import 'package:safaria/shared/widgets/skyline_tab_hero.dart';

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
    final isGuest = ref.watch(guestModeProvider).value ?? false;
    final showBadge =
        !isGuest && ref.watch(hasUnreadNotificationsProvider);
    final userName = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!
        : l10n.homeMockUser;
    final initial = userName.isNotEmpty ? userName.substring(0, 1) : '?';

    return ShellTabScrollView(
      hero: SkylineTabHero(
        child: SkylineTabGreetingRow(
          initial: initial,
          avatarUrl: user?.avatarUrl,
          greeting: l10n.homeGreeting(userName),
          headline: l10n.homeWhereTo,
          trailing: SkylineTabHeroBellButton(
            showBadge: showBadge,
            onTap: () {
              if (isGuest) {
                context.go(
                  AppRoutes.login,
                  extra: const AuthGateArgs(
                    returnTo: NotificationsRoutes.list,
                  ),
                );
              } else {
                context.push(NotificationsRoutes.list);
              }
            },
          ),
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
