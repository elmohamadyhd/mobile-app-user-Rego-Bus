import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
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
  int _transportTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      backgroundColor: AppColors.bgBase,
      body: SingleChildScrollView(
        padding: EdgeInsetsDirectional.only(
          bottom: MainNavBar.scrollBottomPadding(context) +
              MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHero(context),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: HomeSearchCard(
                  selectedTab: _transportTab,
                  onTabChanged: (i) => setState(() => _transportTab = i),
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
          ],
        ),
      ),
      bottomNavigationBar: const Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(14, 0, 14, 16),
            child: MainNavBar(),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userName = l10n.homeMockUser;
    final initial =
        userName.isNotEmpty ? userName.substring(0, 1) : '?';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D6FF2),
            AppColors.primaryDark,
            AppColors.primaryDeep,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.hero),
          bottomRight: Radius.circular(AppRadius.hero),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PositionedDirectional(
            top: -50,
            end: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 24,
            start: -26,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.13),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: AppTypography.title.copyWith(
                            color: AppColors.onHero,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.homeGreeting(userName),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.onHero.withValues(alpha: 0.78),
                            ),
                          ),
                          Text(
                            l10n.homeWhereTo,
                            style: AppTypography.title.copyWith(
                              color: AppColors.onHero,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const _BellButton(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {},
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                AppIcons.bell,
                color: AppColors.onHero,
                size: 22,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 9,
          end: 10,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFBA834),
              border: Border.all(
                color: const Color(0xFF1D6FF2),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
