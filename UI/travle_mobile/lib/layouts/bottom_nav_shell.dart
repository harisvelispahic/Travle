import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

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

  /// Live-push subscription: a role-grant push can force a re-login (see [_onPush]).
  StreamSubscription<NotificationResponse>? _pushSub;
  bool _handlingPromotion = false;

  static const List<String> _titles = ['Home', 'Search', 'Favorites', 'Profile'];

  late final List<Widget> _screens = [
    HomeScreen(onOpenSearch: _openSearch),
    SearchScreen(focusRequests: _searchFocusRequests),
    FavoritesScreen(reloadRequests: _favoritesReloadRequests),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pushSub = context.read<NotificationProvider>().pushes.listen(_onPush);
  }

  void _openSearch() {
    setState(() => _index = 1);
    _searchFocusRequests.value++;
  }

  /// When an admin approves a role application, the applicant is pushed a
  /// `RoleApplicationApproved` notification. If that grant added a *mobile* role the
  /// current token lacks — Curator, which unlocks submitting destinations — the
  /// stateless access token still won't carry it, so we force a re-login: the next
  /// sign-in issues a JWT with the role and the app enables its features. Becoming an
  /// Organizer (a desktop role) grants nothing on mobile, so it never triggers this.
  Future<void> _onPush(NotificationResponse notification) async {
    if (_handlingPromotion || notification.type != 'RoleApplicationApproved') {
      return;
    }
    final auth = context.read<AuthProvider>();
    final gainedMobile = (await auth.newlyGrantedRoles())
        .where(AppRole.mobile.contains)
        .toList();
    if (gainedMobile.isEmpty || !mounted) return;

    _handlingPromotion = true;
    await _promptReauth(gainedMobile.first);
  }

  Future<void> _promptReauth(String role) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.verified_user_outlined),
        title: Text("You're now a $role"),
        content: Text(
          'Your $role application was approved. Please sign in again to unlock '
          'your new $role features.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Sign in again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    // Drop any overlay routes (e.g. an open notification detail) then sign out; the
    // AuthGate routes to login and the next sign-in carries the new role.
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    await context.read<AuthProvider>().logout();
  }

  void _onDestinationSelected(int i) {
    setState(() => _index = i);
    if (i == _favoritesIndex) {
      _favoritesReloadRequests.value++;
    }
  }

  @override
  void dispose() {
    _pushSub?.cancel();
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
