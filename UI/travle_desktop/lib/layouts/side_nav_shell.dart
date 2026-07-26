import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/destinations_moderation_screen.dart';
import '../screens/organizer_destinations_screen.dart';
import '../screens/organizer_tours_screen.dart';
import '../screens/reference/reference_registry.dart';
import '../screens/role_applications_review_screen.dart';

/// Persistent chrome for the management app: a left sidebar (brand + navigation
/// + account/logout) beside a content area. "Reference Data" (admin-only) is an
/// inline expandable group revealing the reference tables; each opens the generic
/// CRUD screen. The remaining destinations are placeholders filled in by their
/// phase (Bookings §Phase 5, Dashboard §Phase 10). Destinations (§Phase 3),
/// My Tours (§Phase 4) and Role Requests are live.
class SideNavShell extends StatefulWidget {
  const SideNavShell({super.key});

  @override
  State<SideNavShell> createState() => _SideNavShellState();
}

/// A flat sidebar destination (not the Reference Data group).
class _Leaf {
  const _Leaf(this.key, this.icon, this.label, {this.builder, this.requiredRole});
  final String key;
  final IconData icon;
  final String label;

  /// Content for this destination; null renders the "coming soon" placeholder.
  final WidgetBuilder? builder;

  /// When set, the leaf is only shown to a user holding this role (e.g. moderation
  /// is admin-only; "My Destinations" is organizer-only).
  final String? requiredRole;
}

class _SideNavShellState extends State<SideNavShell> {
  /// Selected destination: a leaf key, or `ref:<index>` for a reference table.
  String _selectedKey = 'dashboard';
  bool _referenceExpanded = false;

  late final _modules = buildReferenceModules();

  // Leaves shown above/below the Reference Data group, in order.
  static const _topLeaves = <_Leaf>[
    _Leaf('dashboard', Icons.dashboard_outlined, 'Dashboard'),
  ];
  static final _bottomLeaves = <_Leaf>[
    _Leaf(
      'destinations',
      Icons.place_outlined,
      'Destinations',
      builder: (_) => const DestinationsModerationScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'myDestinations',
      Icons.add_location_alt_outlined,
      'My Destinations',
      builder: (_) => const OrganizerDestinationsScreen(),
      requiredRole: AppRole.organizer,
    ),
    _Leaf(
      'myTours',
      Icons.tour_outlined,
      'My Tours',
      builder: (_) => const OrganizerToursScreen(),
      requiredRole: AppRole.organizer,
    ),
    const _Leaf('bookings', Icons.event_note_outlined, 'Bookings'),
    const _Leaf('users', Icons.group_outlined, 'Users'),
    _Leaf(
      'roleRequests',
      Icons.how_to_reg_outlined,
      'Role Requests',
      builder: (_) => const RoleApplicationsReviewScreen(),
      requiredRole: AppRole.admin,
    ),
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

  Iterable<_Leaf> _visible(List<_Leaf> leaves, List<String> roles) =>
      leaves.where((l) => l.requiredRole == null || roles.contains(l.requiredRole));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final auth = context.watch<AuthProvider>();
    final roles = auth.roles;
    final isAdmin = roles.contains(AppRole.admin);

    final (title, content) = _resolveContent(context, roles);

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
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final leaf in _visible(_topLeaves, roles))
                        _navTile(leaf.key, leaf.icon, leaf.label, onPrimary),
                      if (isAdmin) ..._referenceGroup(onPrimary),
                      for (final leaf in _visible(_bottomLeaves, roles))
                        _navTile(leaf.key, leaf.icon, leaf.label, onPrimary),
                    ],
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
                      child: Text(title, style: theme.textTheme.titleLarge),
                    ),
                  ),
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    String key,
    IconData icon,
    String label,
    Color onPrimary, {
    bool child = false,
  }) {
    final selected = _selectedKey == key;
    return ListTile(
      contentPadding: child
          ? const EdgeInsets.only(left: 40, right: TravleTokens.space16)
          : null,
      dense: child,
      leading: Icon(icon, color: onPrimary, size: child ? 20 : 24),
      title: Text(label, style: TextStyle(color: onPrimary)),
      selected: selected,
      selectedTileColor: onPrimary.withValues(alpha: 0.16),
      onTap: () => setState(() => _selectedKey = key),
    );
  }

  List<Widget> _referenceGroup(Color onPrimary) {
    return [
      ListTile(
        leading: Icon(Icons.list_alt_outlined, color: onPrimary),
        title: Text('Reference Data', style: TextStyle(color: onPrimary)),
        trailing: Icon(
          _referenceExpanded ? Icons.expand_less : Icons.expand_more,
          color: onPrimary,
        ),
        onTap: () =>
            setState(() => _referenceExpanded = !_referenceExpanded),
      ),
      if (_referenceExpanded)
        for (var i = 0; i < _modules.length; i++)
          _navTile('ref:$i', _modules[i].icon, _modules[i].title, onPrimary,
              child: true),
    ];
  }

  /// Resolves the current selection to its (title, content) pair.
  (String, Widget) _resolveContent(BuildContext context, List<String> roles) {
    final isAdmin = roles.contains(AppRole.admin);
    if (_selectedKey.startsWith('ref:') && isAdmin) {
      final index = int.parse(_selectedKey.substring(4));
      if (index >= 0 && index < _modules.length) {
        final module = _modules[index];
        return (module.title, module.builder(context));
      }
    }

    for (final leaf in [..._topLeaves, ..._bottomLeaves]) {
      if (leaf.key == _selectedKey &&
          (leaf.requiredRole == null || roles.contains(leaf.requiredRole))) {
        return (
          leaf.label,
          leaf.builder != null
              ? leaf.builder!(context)
              : _Placeholder(title: leaf.label),
        );
      }
    }

    // Selection no longer available (e.g. role changed) — fall back to Dashboard.
    return ('Dashboard', const _Placeholder(title: 'Dashboard'));
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
