import 'package:flutter/material.dart';

import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../widgets/notification_bell.dart';

/// Persistent chrome for authenticated mobile users: an app bar over the
/// four-tab bottom navigation (Home · Search · Favorites · Profile). An
/// [IndexedStack] keeps each tab's state (e.g. search results, scroll position)
/// alive across switches; tapping the Home search bar jumps to the Search tab and
/// focuses its field via [_searchFocusRequests].
///
/// Session-affecting live pushes (a role grant/revoke, suspension) are handled one
/// level up by the AuthGate, which owns the silent-refresh / re-login flow.
class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  static const int _favoritesIndex = 2;

  /// Bumped to signal the Search tab to take focus when opened from Home.
  final ValueNotifier<int> _searchFocusRequests = ValueNotifier<int>(0);

  /// Bumped each time the Favorites tab is opened, so its lists reload (favorites
  /// may have changed from a details screen since the tab was last seen).
  final ValueNotifier<int> _favoritesReloadRequests = ValueNotifier<int>(0);

  static const List<String> _titles = ['Home', 'Search', 'Favorites', 'Profile'];

  late final List<Widget> _screens = [
    HomeScreen(onOpenSearch: _openSearch),
    SearchScreen(focusRequests: _searchFocusRequests),
    FavoritesScreen(reloadRequests: _favoritesReloadRequests),
    const ProfileScreen(),
  ];

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favorites'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
