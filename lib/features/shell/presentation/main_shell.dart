import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/features/shell/presentation/widgets/main_nav_bar.dart';
import 'package:rego/shared/widgets/double_back_to_exit.dart';

/// Root scaffold for the signed-in experience. Hosts the five primary tabs in
/// an [IndexedStack] (per-tab state preserved) with [MainNavBar] as the shared
/// bottom navigation. Full-screen flows (booking, auth) live on the root
/// navigator above this shell and therefore hide the bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // `initialLocation: true` when re-tapping the active tab pops that branch
    // back to its root; otherwise it just switches branches, preserving state.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExit(
      onSingleBack: navigationShell.currentIndex != 0
          ? () => navigationShell.goBranch(0)
          : null,
      child: Scaffold(
        // Keep the floating bar still when the keyboard opens; branch bodies pad
        // for the keyboard themselves.
        resizeToAvoidBottomInset: false,
        // Let branch content sit behind the transparent bar; the bar's measured
        // height is reported to bodies via MediaQuery padding.
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 16),
              child: MainNavBar(
                currentIndex: navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
