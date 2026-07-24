import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/role_applications_review_screen.dart';

/// Persistent chrome for the management app: a left sidebar (brand + navigation
/// + account/logout) beside a content area. Most destinations are placeholders
/// now; each is filled in by its phase (Reference Data §Phase 2, Destinations
/// §Phase 3, Tours §Phase 4, Bookings §Phase 5, Dashboard §Phase 10). Role
/// Requests (admin-only) is live.
class SideNavShell extends StatefulWidget {
  const SideNavShell({super.key});

  @override
  State<SideNavShell> createState() => _SideNavShellState();
}

class _NavItem {
  const _NavItem(this.icon, this.label, {this.builder});
  final IconData icon;
  final String label;

  /// Content for this destination; null renders the "coming soon" placeholder.
  final WidgetBuilder? builder;
}

class _SideNavShellState extends State<SideNavShell> {
  int _index = 0;

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
    final isAdmin = auth.roles.contains(AppRole.admin);

    final items = <_NavItem>[
      const _NavItem(Icons.dashboard_outlined, 'Dashboard'),
      const _NavItem(Icons.list_alt_outlined, 'Reference Data'),
      const _NavItem(Icons.place_outlined, 'Destinations'),
      const _NavItem(Icons.tour_outlined, 'Tours'),
      const _NavItem(Icons.event_note_outlined, 'Bookings'),
      const _NavItem(Icons.group_outlined, 'Users'),
      // Role application moderation is admin-only (spec §2.4).
      if (isAdmin)
        _NavItem(
          Icons.how_to_reg_outlined,
          'Role Requests',
          builder: (_) => const RoleApplicationsReviewScreen(),
        ),
    ];
    final index = _index.clamp(0, items.length - 1);
    final current = items[index];

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
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final selected = i == index;
                      return ListTile(
                        leading: Icon(items[i].icon, color: onPrimary),
                        title: Text(items[i].label,
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
                      child: Text(current.label,
                          style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
                Expanded(
                  child: current.builder != null
                      ? current.builder!(context)
                      : _Placeholder(title: current.label),
                ),
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
