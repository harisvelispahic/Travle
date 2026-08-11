import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/account_screen.dart';
import '../screens/admin_bookings_screen.dart';
import '../screens/admin_payments_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/destinations_moderation_screen.dart';
import '../screens/organizer_stats_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/organizer_bookings_screen.dart';
import '../screens/organizer_destinations_screen.dart';
import '../screens/organizer_reviews_screen.dart';
import '../screens/organizer_tours_screen.dart';
import '../screens/reference/reference_registry.dart';
import '../screens/notification_detail_screen.dart';
import '../screens/reviews_moderation_screen.dart';
import '../screens/role_applications_review_screen.dart';
import '../screens/users_screen.dart';
import '../widgets/notification_bell.dart';
import '../widgets/notification_toast.dart';

/// Persistent chrome for the management app: a left sidebar (brand + navigation
/// + account/logout) beside a content area. "Reference Data" (admin-only) is an
/// inline expandable group revealing the reference tables; each opens the generic
/// CRUD screen. Admins land on the Dashboard and have the Reports module (§Phase 11);
/// organizers land on their Statistics screen (§Phase 11). All other destinations
/// are live from their respective phases.
class SideNavShell extends StatefulWidget {
  const SideNavShell({super.key});

  @override
  State<SideNavShell> createState() => _SideNavShellState();
}

/// A flat sidebar destination (not the Reference Data group).
class _Leaf {
  const _Leaf(
    this.key,
    this.icon,
    this.label, {
    this.builder,
    this.requiredRole,
  });
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

  /// One-time guard: pick a role-appropriate landing screen on the first build with
  /// known roles (the Dashboard is admin-only, so organizers open their Statistics).
  bool _defaultApplied = false;

  late final _modules = buildReferenceModules();

  // Live notification toasts (SignalR): a stack of transient top-right cards, each
  // auto-dismissed after a few seconds. The DB row + bell badge remain the durable
  // record; the toast is only the real-time nudge.
  StreamSubscription<NotificationResponse>? _pushSub;
  final List<_Toast> _toasts = <_Toast>[];
  final Map<Key, Timer> _toastTimers = <Key, Timer>{};
  static const int _maxToasts = 4;
  static const Duration _toastDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _pushSub = context.read<NotificationProvider>().pushes.listen(_onPush);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _onPush(NotificationResponse notification) {
    if (!mounted) return;
    // Auth-change pushes about our own account (suspension, role grant/revoke) are handled by the
    // AuthGate (silent refresh or a re-login dialog) — don't also surface them as a toast.
    if (sessionAffectingNotificationTypes.contains(notification.type)) return;
    final toast = _Toast(notification);
    setState(() {
      _toasts.insert(0, toast);
      if (_toasts.length > _maxToasts) {
        final removed = _toasts.removeLast();
        _toastTimers.remove(removed.key)?.cancel();
      }
    });
    _toastTimers[toast.key] = Timer(
      _toastDuration,
      () => _dismissToast(toast.key),
    );
  }

  void _dismissToast(Key key) {
    _toastTimers.remove(key)?.cancel();
    final index = _toasts.indexWhere((t) => t.key == key);
    if (index == -1) return;
    if (mounted) {
      setState(() => _toasts.removeAt(index));
    } else {
      _toasts.removeAt(index);
    }
  }

  void _openToast(_Toast toast) {
    _dismissToast(toast.key);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          notification: toast.notification,
          onNavigateToSection: (key) => setState(() => _selectedKey = key),
        ),
      ),
    );
  }

  // Leaves shown above/below the Reference Data group, in order.
  static final _topLeaves = <_Leaf>[
    _Leaf(
      'dashboard',
      Icons.dashboard_outlined,
      'Dashboard',
      builder: (_) => const DashboardScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'statistics',
      Icons.insights_outlined,
      'Statistics',
      builder: (_) => const OrganizerStatsScreen(),
      requiredRole: AppRole.organizer,
    ),
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
    _Leaf(
      'tourBookings',
      Icons.event_note_outlined,
      'Tour Bookings',
      builder: (_) => const OrganizerBookingsScreen(),
      requiredRole: AppRole.organizer,
    ),
    _Leaf(
      'myTourReviews',
      Icons.reviews_outlined,
      'Tour Reviews',
      builder: (_) => const OrganizerReviewsScreen(),
      requiredRole: AppRole.organizer,
    ),
    _Leaf(
      'allBookings',
      Icons.event_available_outlined,
      'All Bookings',
      builder: (_) => const AdminBookingsScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'payments',
      Icons.receipt_long_outlined,
      'Payments',
      builder: (_) => const AdminPaymentsScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'reports',
      Icons.assessment_outlined,
      'Reports',
      builder: (_) => const ReportsScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'reviews',
      Icons.rate_review_outlined,
      'Reviews',
      builder: (_) => const ReviewsModerationScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'users',
      Icons.group_outlined,
      'Users',
      builder: (_) => const UsersScreen(),
      requiredRole: AppRole.admin,
    ),
    _Leaf(
      'roleRequests',
      Icons.how_to_reg_outlined,
      'Role Requests',
      builder: (_) => const RoleApplicationsReviewScreen(),
      requiredRole: AppRole.admin,
    ),
  ];

  Widget _buildToasts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final toast in _toasts)
          Padding(
            key: toast.key,
            padding: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: NotificationToast(
              notification: toast.notification,
              onTap: () => _openToast(toast),
              onDismiss: () => _dismissToast(toast.key),
            ),
          ),
      ],
    );
  }

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

  Iterable<_Leaf> _visible(List<_Leaf> leaves, List<String> roles) => leaves
      .where((l) => l.requiredRole == null || roles.contains(l.requiredRole));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final auth = context.watch<AuthProvider>();
    final roles = auth.roles;
    final isAdmin = roles.contains(AppRole.admin);

    // On the first build with known roles, land a non-admin organizer on their
    // Statistics screen (the Dashboard is admin-only).
    if (!_defaultApplied && roles.isNotEmpty) {
      _defaultApplied = true;
      if (!isAdmin && roles.contains(AppRole.organizer)) {
        _selectedKey = 'statistics';
      }
    }

    final (title, content) = _resolveContent(context, roles);

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              Material(
                // A Material (not a plain coloured Container) so the nav ListTiles paint
                // their selection highlight and ink on this forest surface directly.
                color: theme.colorScheme.primary,
                child: SizedBox(
                  width: 248,
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
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final leaf in _visible(_topLeaves, roles))
                              _navTile(
                                leaf.key,
                                leaf.icon,
                                leaf.label,
                                onPrimary,
                              ),
                            if (isAdmin) ..._referenceGroup(onPrimary),
                            for (final leaf in _visible(_bottomLeaves, roles))
                              _navTile(
                                leaf.key,
                                leaf.icon,
                                leaf.label,
                                onPrimary,
                              ),
                          ],
                        ),
                      ),
                      Divider(
                        color: onPrimary.withValues(alpha: 0.2),
                        height: 1,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.account_circle_outlined,
                          color: onPrimary,
                        ),
                        title: Text(
                          auth.username ?? 'Signed in',
                          style: TextStyle(color: onPrimary),
                        ),
                        subtitle: Text(
                          auth.roles.isEmpty
                              ? 'No roles'
                              : auth.roles.join(' · '),
                          style: TextStyle(
                            color: onPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: onPrimary.withValues(alpha: 0.7),
                        ),
                        selected: _selectedKey == 'account',
                        selectedTileColor: onPrimary.withValues(alpha: 0.16),
                        onTap: () => setState(() => _selectedKey = 'account'),
                      ),
                      ListTile(
                        leading: Icon(Icons.logout, color: onPrimary),
                        title: Text(
                          'Log out',
                          style: TextStyle(color: onPrimary),
                        ),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Material(
                      color: theme.colorScheme.surface,
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: TravleTokens.space16,
                          vertical: TravleTokens.space8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            NotificationBell(
                              onNavigateToSection: (key) =>
                                  setState(() => _selectedKey = key),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
          if (_toasts.isNotEmpty)
            Positioned(
              top: 72,
              right: TravleTokens.space16,
              child: _buildToasts(),
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
        onTap: () => setState(() => _referenceExpanded = !_referenceExpanded),
      ),
      if (_referenceExpanded)
        for (var i = 0; i < _modules.length; i++)
          _navTile(
            'ref:$i',
            _modules[i].icon,
            _modules[i].title,
            onPrimary,
            child: true,
          ),
    ];
  }

  /// Resolves the current selection to its (title, content) pair.
  (String, Widget) _resolveContent(BuildContext context, List<String> roles) {
    final isAdmin = roles.contains(AppRole.admin);
    // The signed-in user's own account — available to every role.
    if (_selectedKey == 'account') {
      return ('Account', const AccountScreen());
    }
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

/// One live notification toast in the shell's queue; [key] gives it a stable
/// identity for the list + its auto-dismiss timer.
class _Toast {
  _Toast(this.notification) : key = UniqueKey();

  final NotificationResponse notification;
  final Key key;
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
