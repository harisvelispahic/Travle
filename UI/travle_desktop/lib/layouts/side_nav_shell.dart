import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Persistent chrome for the management app: a left sidebar (brand + navigation
/// + account/logout) beside a content area. Destinations are placeholders now;
/// each is filled in by its phase (Reference Data §Phase 2, Destinations §Phase 3,
/// Tours §Phase 4, Bookings §Phase 5, Users §Phase 1+, Dashboard §Phase 10).
class SideNavShell extends StatefulWidget {
  const SideNavShell({super.key});

  @override
  State<SideNavShell> createState() => _SideNavShellState();
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _SideNavShellState extends State<SideNavShell> {
  int _index = 0;

  static const List<_NavItem> _items = [
    _NavItem(Icons.dashboard_outlined, 'Dashboard'),
    _NavItem(Icons.list_alt_outlined, 'Reference Data'),
    _NavItem(Icons.place_outlined, 'Destinations'),
    _NavItem(Icons.tour_outlined, 'Tours'),
    _NavItem(Icons.event_note_outlined, 'Bookings'),
    _NavItem(Icons.group_outlined, 'Users'),
  ];

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (confirmed) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 248,
            color: theme.colorScheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(TravleTokens.space24),
                  child: Row(
                    children: [
                      Icon(Icons.travel_explore, color: onPrimary),
                      const SizedBox(width: TravleTokens.space12),
                      Text(
                        'Travle',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: onPrimary),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final selected = i == _index;
                      return ListTile(
                        leading: Icon(_items[i].icon, color: onPrimary),
                        title: Text(_items[i].label,
                            style: TextStyle(color: onPrimary)),
                        selected: selected,
                        selectedTileColor: onPrimary.withValues(alpha: 0.16),
                        onTap: () => setState(() => _index = i),
                      );
                    },
                  ),
                ),
                Divider(color: onPrimary.withValues(alpha: 0.2), height: 1),
                ListTile(
                  leading: Icon(Icons.account_circle_outlined, color: onPrimary),
                  title: Text(auth.username ?? 'Signed in',
                      style: TextStyle(color: onPrimary)),
                  subtitle: Text(
                    auth.roles.isEmpty ? 'No roles' : auth.roles.join(' · '),
                    style: TextStyle(color: onPrimary.withValues(alpha: 0.7)),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: onPrimary),
                  title: Text('Log out', style: TextStyle(color: onPrimary)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Material(
                  color: theme.colorScheme.surface,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(TravleTokens.space16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_items[_index].label,
                          style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
                Expanded(child: _Placeholder(title: _items[_index].label)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Coming soon', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
