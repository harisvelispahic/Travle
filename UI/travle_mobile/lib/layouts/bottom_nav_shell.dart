import 'package:flutter/material.dart';

import '../screens/favorites_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';

/// Persistent chrome for authenticated mobile users: an app bar over the
/// four-tab bottom navigation (Home · Search · Favorites · Profile). An
/// [IndexedStack] keeps each tab's state (e.g. search results, scroll position)
/// alive across switches; tapping the Home search bar jumps to the Search tab and
/// focuses its field via [_searchFocusRequests].
class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  /// Bumped to signal the Search tab to take focus when opened from Home.
  final ValueNotifier<int> _searchFocusRequests = ValueNotifier<int>(0);

  static const List<String> _titles = ['Home', 'Search', 'Favorites', 'Profile'];

  late final List<Widget> _screens = [
    HomeScreen(onOpenSearch: _openSearch),
    SearchScreen(focusRequests: _searchFocusRequests),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  void _openSearch() {
    setState(() => _index = 1);
    _searchFocusRequests.value++;
  }

  @override
  void dispose() {
    _searchFocusRequests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
