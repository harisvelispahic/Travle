import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/map_browse_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../widgets/notification_bell.dart';

/// Persistent chrome for authenticated mobile users: an app bar over the
/// five-tab bottom navigation (Home · Search · **Map** · Favorites · Profile). The
/// Map tab sits dead-centre as a raised, forest-green circle — the app's signature
/// action, lifted above the bar to point it out. An [IndexedStack] keeps each tab's
/// state (search results, map camera, scroll position) alive across switches;
/// tapping the Home search bar jumps to the Search tab and focuses its field via
/// [_searchFocusRequests].
///
/// Session-affecting live pushes (a role grant/revoke, suspension) are handled one
/// level up by the AuthGate, which owns the silent-refresh / re-login flow. After a
/// role loss it bumps [homeReset] so this shell returns to the Home tab, keeping the
/// user out of a now-forbidden context.
class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key, this.homeReset});

  /// Bumped by the AuthGate to force the shell back to the Home tab (e.g. after a
  /// role revoke). Null in contexts that never need to command a reset.
  final ValueListenable<int>? homeReset;

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  static const int _mapIndex = 2;
  static const int _favoritesIndex = 3;

  /// Bumped to signal the Search tab to take focus when opened from Home.
  final ValueNotifier<int> _searchFocusRequests = ValueNotifier<int>(0);

  /// Bumped each time the Favorites tab is opened, so its lists reload (favorites
  /// may have changed from a details screen since the tab was last seen).
  final ValueNotifier<int> _favoritesReloadRequests = ValueNotifier<int>(0);

  static const List<String> _titles = [
    'Home',
    'Search',
    'Map',
    'Favorites',
    'Profile',
  ];

  late final List<Widget> _screens = [
    HomeScreen(onOpenSearch: _openSearch),
    SearchScreen(focusRequests: _searchFocusRequests),
    const MapBrowseScreen(),
    FavoritesScreen(reloadRequests: _favoritesReloadRequests),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    widget.homeReset?.addListener(_resetToHome);
  }

  /// Returns to the Home tab when the AuthGate signals a role loss.
  void _resetToHome() {
    if (mounted && _index != 0) setState(() => _index = 0);
  }

  void _openSearch() {
    setState(() => _index = 1);
    _searchFocusRequests.value++;
  }

  void _onDestinationSelected(int i) {
    setState(() => _index = i);
    if (i == _favoritesIndex) {
      _favoritesReloadRequests.value++;
    }
  }

  @override
  void dispose() {
    widget.homeReset?.removeListener(_resetToHome);
    _searchFocusRequests.dispose();
    _favoritesReloadRequests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [NotificationBell()],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _TravleBottomBar(
        selectedIndex: _index,
        mapIndex: _mapIndex,
        onSelected: _onDestinationSelected,
      ),
    );
  }
}

/// The custom five-slot bottom bar with a raised centre Map action. Built by hand
/// (rather than a Material [NavigationBar]) so the lifted circle can straddle the
/// top edge cleanly, without a selection indicator peeking from behind it.
class _TravleBottomBar extends StatelessWidget {
  const _TravleBottomBar({
    required this.selectedIndex,
    required this.mapIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final int mapIndex;
  final ValueChanged<int> onSelected;

  static const double _barHeight = 64;

  // How far the centre circle lifts above the bar's top edge.
  static const double _lift = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + _lift + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The bar surface pinned to the bottom, with the four side items.
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 8,
              child: SizedBox(
                height: _barHeight + bottomInset,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Home',
                        selected: selectedIndex == 0,
                        onTap: () => onSelected(0),
                      ),
                      _NavItem(
                        icon: Icons.search_outlined,
                        selectedIcon: Icons.search,
                        label: 'Search',
                        selected: selectedIndex == 1,
                        onTap: () => onSelected(1),
                      ),
                      // Reserved centre slot — the raised Map button overlays it.
                      const Expanded(child: SizedBox.shrink()),
                      _NavItem(
                        icon: Icons.favorite_outline,
                        selectedIcon: Icons.favorite,
                        label: 'Favorites',
                        selected: selectedIndex == 3,
                        onTap: () => onSelected(3),
                      ),
                      _NavItem(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profile',
                        selected: selectedIndex == 4,
                        onTap: () => onSelected(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The lifted centre Map button, aligned over the reserved slot.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: _RaisedMapButton(
                selected: selectedIndex == mapIndex,
                onTap: () => onSelected(mapIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the four flanking tabs: an icon (filled when selected) over a label,
/// tinted with the primary colour while selected.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: TravleTokens.space4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The signature raised centre action: a forest-green circle ringed by the bar
/// colour (so it reads as lifted off the surface) with a white map glyph, over a
/// "Map" label. Emphasised further while its tab is active.
class _RaisedMapButton extends StatelessWidget {
  const _RaisedMapButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              // A ring in the bar colour separates the circle from the surface,
              // giving the lifted look without a blurred shadow.
              border: Border.all(color: scheme.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: selected ? 0.5 : 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              selected ? Icons.map : Icons.map_outlined,
              color: scheme.onPrimary,
              size: 28,
            ),
          ),
          const SizedBox(height: TravleTokens.space4),
          Text(
            'Map',
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
