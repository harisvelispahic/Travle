import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';
import '../widgets/bookings_bar_chart.dart';
import '../widgets/simple_data_table.dart';

/// The organizer statistics screen (course §2.3): bookings, revenue and average
/// rating across the organizer's own tours, with a bookings-per-month chart and a
/// searchable per-tour breakdown. Scoped server-side to the caller via
/// `GET /Reports/organizer-stats`.
class OrganizerStatsScreen extends StatefulWidget {
  const OrganizerStatsScreen({super.key});

  @override
  State<OrganizerStatsScreen> createState() => _OrganizerStatsScreenState();
}

class _OrganizerStatsScreenState extends State<OrganizerStatsScreen> {
  final ReportProvider _provider = ReportProvider();

  OrganizerStatsResponse? _data;
  bool _loading = true;
  String? _error;
  String _tourFilter = '';

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
      final data = await _provider.getOrganizerStats();
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

  static String _rating(double value) =>
      value <= 0 ? '—' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        message: 'Could not load your statistics',
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
          _bookingTiles(data),
          const SizedBox(height: TravleTokens.space12),
          _revenueTiles(data),
          const SizedBox(height: TravleTokens.space16),
          _chartCard(context, data),
          const SizedBox(height: TravleTokens.space16),
          _toursCard(context, data),
        ],
      ),
    );
  }

  Widget _bookingTiles(OrganizerStatsResponse data) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatTile(
              label: 'Total bookings',
              value: data.totalBookings.toString(),
              sub: '${data.pendingBookings} pending',
              icon: Icons.event_note_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Confirmed',
              value: data.confirmedBookings.toString(),
              icon: Icons.verified_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Completed',
              value: data.completedBookings.toString(),
              icon: Icons.task_alt_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Cancelled',
              value: data.cancelledBookings.toString(),
              icon: Icons.cancel_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Average rating',
              value: _rating(data.averageRating),
              sub:
                  '${data.reviewCount} ${data.reviewCount == 1 ? 'review' : 'reviews'}',
              icon: Icons.star_outline,
            ),
          ),
        ],
      ),
    );
  }

  // Revenue as a reconciling breakdown: Gross − Refunds − Platform fee = Net earnings.
  Widget _revenueTiles(OrganizerStatsResponse data) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatTile(
              label: 'Gross revenue',
              value: formatPrice(data.grossRevenue),
              icon: Icons.payments_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Refunds',
              value: formatPrice(data.totalRefunded),
              icon: Icons.undo_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Platform fee',
              value: formatPrice(data.platformCommission),
              icon: Icons.percent_outlined,
            ),
          ),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: StatTile(
              label: 'Net earnings',
              value: formatPrice(data.netEarnings),
              sub: 'after refunds & fee',
              icon: Icons.account_balance_wallet_outlined,
              emphasize: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(BuildContext context, OrganizerStatsResponse data) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings per month', style: theme.textTheme.titleMedium),
            Text(
              'Across your tours · last 12 months',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TravleTokens.space16),
            BookingsBarChart(points: data.bookingsPerMonth),
          ],
        ),
      ),
    );
  }

  Widget _toursCard(BuildContext context, OrganizerStatsResponse data) {
    final theme = Theme.of(context);
    // Accent-aware filter mirroring the backend search ("Poc" matches "Počitelj").
    final query = _tourFilter.trim();
    final tours = query.isEmpty
        ? data.tours
        : data.tours
              .where((t) => accentAwareContains(t.tourName, query))
              .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tour performance', style: theme.textTheme.titleMedium),
            const SizedBox(height: TravleTokens.space12),
            TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                labelText: 'Search tours',
                hintText: 'Filter by tour name',
              ),
              onChanged: (value) => setState(() => _tourFilter = value),
            ),
            const SizedBox(height: TravleTokens.space12),
            if (data.tours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TravleTokens.space16,
                ),
                child: Text(
                  'You have no tours yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (tours.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TravleTokens.space16,
                ),
                child: Text(
                  'No tours match "$_tourFilter".',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              SimpleDataTable(
                boldFirstColumn: true,
                columns: const [
                  SimpleColumn('Tour', flex: 4),
                  SimpleColumn('Bookings', numeric: true, flex: 2),
                  SimpleColumn('Net earnings', numeric: true, flex: 3),
                  SimpleColumn('Rating', numeric: true, flex: 2),
                ],
                rows: [
                  for (final tour in tours)
                    [
                      tour.tourName,
                      tour.bookings.toString(),
                      formatPrice(tour.netEarnings),
                      tour.averageRating <= 0
                          ? '—'
                          : '${_rating(tour.averageRating)} (${tour.reviewCount})',
                    ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
