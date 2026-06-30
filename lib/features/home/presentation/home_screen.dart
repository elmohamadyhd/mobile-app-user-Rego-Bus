import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/home/presentation/widgets/home_search_card.dart';
import 'package:rego/features/home/presentation/widgets/main_nav_bar.dart';
import 'package:rego/features/home/presentation/widgets/popular_destinations.dart';
import 'package:rego/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(context),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: HomeSearchCard(
                      selectedTab: _selectedTab,
                      onTabChanged: (i) => setState(() => _selectedTab = i),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: PopularDestinations(),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 30,
            child: MainNavBar(
              activeTab: _selectedTab,
              onTabTap: (i) => setState(() => _selectedTab = i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D6FF2), AppColors.primaryDark, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    child: const Icon(AppIcons.person, color: AppColors.onPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeGoodMorning,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        l10n.homeMockUser,
                        style: AppTypography.title.copyWith(color: AppColors.onPrimary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const _BellButton(),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l10n.homeHeroHeadline,
                style: AppTypography.display.copyWith(color: AppColors.onPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _circle(12, 0.3),
                  const SizedBox(width: 8),
                  _circle(8, 0.2),
                  const SizedBox(width: 8),
                  _circle(6, 0.15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(AppIcons.bell, color: AppColors.onPrimary),
          onPressed: () {},
        ),
        const Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(radius: 4, backgroundColor: AppColors.secondary),
        ),
      ],
    );
  }
}
