import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routes/app_router.dart';
import '../services/tab_navigation_service.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({
    super.key,
    required this.navigationShell,
  });

  void _onTabSelected(
    BuildContext context,
    int index,
  ) {
    final isCurrentTab =
        navigationShell.currentIndex == index;

    if (!isCurrentTab) {
      // Switching to a different tab: restore that tab's previous state.
      navigationShell.goBranch(
        index,
        initialLocation: false,
      );
      return;
    }

    // Tapping the currently active tab.
    // Get the navigator key for the active branch.
    GlobalKey<NavigatorState>? branchKey;

    switch (index) {
      case 0:
        branchKey = homeNavigatorKey;
        break;
      case 1:
        branchKey = libraryNavigatorKey;
        break;
      case 2:
        branchKey = discoverNavigatorKey;
        break;
      case 3:
        branchKey = profileNavigatorKey;
        break;
    }

    if (branchKey == null) {
      return;
    }

    final branchNavigator = branchKey.currentState;

    if (branchNavigator == null) {
      return;
    }

    final hasChildPage = branchNavigator.canPop();

    if (hasChildPage) {
      // First tap while a child page is open: pop it.
      branchNavigator.maybePop();
      return;
    }

    // Already on the root page: scroll to top.
    switch (index) {
      case 0:
        TabNavigationService.notifyHomeTabTapped();
        break;
      case 1:
        TabNavigationService.notifyLibraryTabTapped();
        break;
      case 2:
        TabNavigationService.notifyDiscoverTabTapped();
        break;
      case 3:
        TabNavigationService.notifyProfileTabTapped();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            14,
            0,
            14,
            14,
          ),
          child: _PremiumPillNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onSelected: (index) {
              _onTabSelected(context, index);
            },
          ),
        ),
      ),
    );
  }
}

class _PremiumPillNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const _PremiumPillNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final selectedBackground =
        colorScheme.primary.withValues(alpha: 0.22);

    return Container(
      height: 78,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(42),
        border: Border.all(
          color: colorScheme.outline,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colorScheme.brightness ==
                      Brightness.dark
                  ? 0.35
                  : 0.13,
            ),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(
              alpha: colorScheme.brightness ==
                      Brightness.dark
                  ? 0.20
                  : 0.06,
            ),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _PremiumNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: 'Home',
            selected: currentIndex == 0,
            selectedBackground: selectedBackground,
            onTap: () => onSelected(0),
          ),
          _PremiumNavItem(
            icon: Icons.video_library_outlined,
            selectedIcon: Icons.video_library,
            label: 'Library',
            selected: currentIndex == 1,
            selectedBackground: selectedBackground,
            onTap: () => onSelected(1),
          ),
          _PremiumNavItem(
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore,
            label: 'Discover',
            selected: currentIndex == 2,
            selectedBackground: selectedBackground,
            onTap: () => onSelected(2),
          ),
          _PremiumNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: 'Profile',
            selected: currentIndex == 3,
            selectedBackground: selectedBackground,
            onTap: () => onSelected(3),
          ),
        ],
      ),
    );
  }
}

class _PremiumNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color selectedBackground;
  final VoidCallback onTap;

  const _PremiumNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.selectedBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(36),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 160,
            ),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? selectedBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(34),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 120,
                  ),
                  transitionBuilder:
                      (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: child,
                    );
                  },
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey<bool>(selected),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}