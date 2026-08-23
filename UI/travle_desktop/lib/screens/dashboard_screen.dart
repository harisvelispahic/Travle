import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import '../widgets/bookings_bar_chart.dart';

/// The admin dashboard (course §2.4): headline metric tiles, the bookings-per-month
/// chart, and a recent-activity feed. Read-only overview backed by `GET /Reports/dashboard`.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportProvider _provider = ReportProvider();

  DashboardResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _provider.getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: 'Could not load the dashboard',
        hint: _error,
        action: FilledButton.tonalIcon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(TravleTokens.space16),
        children: [
          _MetricsRow(data: data),
          const SizedBox(height: TravleTokens.space16),
          _ChartCard(points: data.bookingsPerMonth),
          const SizedBox(height: TravleTokens.space16),
          _ActivityCard(items: data.recentActivity),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.data});

  final DashboardResponse data;

  static const _gap = TravleTokens.space12;

  @override
  Widget build(BuildContext context) {
    final pending = data.pendingRoleApplications + data.pendingDestinations;
    final newUsers = data.newUsersThisMonth;
    final tiles = <Widget>[
      StatTile(
        label: 'Users',
        value: data.totalUsers.toString(),
        sub: newUsers == 1
            ? '1 new this month'
            : '$newUsers new this month',
        icon: Icons.group_outlined,
      ),
      StatTile(
        label: 'Bookings',
        value: data.totalBookings.toString(),
        sub: 'all time',
        icon: Icons.receipt_long_outlined,
      ),
      StatTile(
        label: 'Active tours',
        value: data.activeTours.toString(),
        sub: 'with upcoming dates',
        icon: Icons.tour_outlined,
      ),
      StatTile(
        label: 'Pending requests',
        value: pending.toString(),
        sub: '${data.pendingRoleApplications} applications · '
            '${data.pendingDestinations} destinations',
        icon: Icons.pending_actions_outlined,
      ),
      StatTile(
        label: 'Revenue this month',
        value: formatPrice(data.monthlyNetRevenue),
        sub: 'net of refunds',
        icon: Icons.account_balance_wallet_outlined,
        emphasize: true,
      ),
    ];

    // Flow the tiles instead of forcing one row: five never fit legibly on a
    // narrow window, and an ellipsized money figure is worse than a second row.
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
                ? 3
                : 2;
        final width =
            (constraints.maxWidth - _gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.points});

  final List<MonthlyBookingPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings per month', style: theme.textTheme.titleMedium),
            Text(
              'Last 12 months',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TravleTokens.space16),
            BookingsBarChart(points: points),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.items});

  final List<DashboardActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent activity', style: theme.textTheme.titleMedium),
            const SizedBox(height: TravleTokens.space8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TravleTokens.space16,
                ),
                child: Text(
                  'No recent activity yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final item in items) _ActivityRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final DashboardActivityItem item;

  static const Map<String, IconData> _icons = {
    'Booking': Icons.event_available_outlined,
    'RoleApplication': Icons.how_to_reg_outlined,
    'Destination': Icons.place_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icons[item.kind] ?? Icons.notifications_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Text(
            _timeAgo(item.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  // Compact "x ago" from a server UTC instant (an audit timestamp → device zone).
  static String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().toUtc().difference(asUtcInstant(timestamp));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return formatDate(deviceLocalTime(timestamp));
  }
}
