import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/booking_display.dart';
import '../widgets/booking_review_card.dart';
import '../widgets/pager_bar.dart';

/// Whether the list shows upcoming departures or past ones — each with the order
/// that reads best: soonest-first for upcoming, most-recent-first for past.
enum _Timeframe { upcoming, past }

/// Admin's read-only view of every booking in the system (`GET /Bookings`),
/// paginated, filterable by status and split into upcoming / past departures.
/// Bookings are never edited here — the admin oversees; organizers act.
/// Transitions happen only through the state machine.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  static const _pageSize = 20;

  int? _statusId; // null = all statuses
  _Timeframe _timeframe = _Timeframe.upcoming;
  int _page = 1;
  int? _totalCount;
  bool _loading = true;
  String? _error;
  List<BookingResponse> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Reloads from page 1 — for anything that changes *which* bookings match.
  void _reload() {
    _page = 1;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Split by the schedule's departure relative to now, ordered so the most
      // relevant row is first: upcoming → soonest first; past → most recent first.
      final now = DateTime.now().toUtc();
      final upcoming = _timeframe == _Timeframe.upcoming;
      final result = await context.read<BookingProvider>().get(
        filter: {
          'page': _page,
          'pageSize': _pageSize,
          'includeTotalCount': true,
          if (_statusId != null) 'statusId': _statusId,
          if (upcoming) 'fromDate': now else 'toDate': now,
          'sortBy': upcoming ? 'TourSchedule.StartsAt' : 'TourSchedule.StartsAt desc',
        },
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _totalCount = result.totalCount;
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

  void _goToPage(int page) {
    setState(() => _page = page);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<_Timeframe>(
                segments: const [
                  ButtonSegment(
                    value: _Timeframe.upcoming,
                    label: Text('Upcoming'),
                    icon: Icon(Icons.event_available_outlined),
                  ),
                  ButtonSegment(
                    value: _Timeframe.past,
                    label: Text('Past'),
                    icon: Icon(Icons.history),
                  ),
                ],
                selected: {_timeframe},
                onSelectionChanged: _loading
                    ? null
                    : (selection) {
                        setState(() => _timeframe = selection.first);
                        _reload();
                      },
              ),
              const SizedBox(width: TravleTokens.space16),
              DropdownButton<int?>(
                value: _statusId,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _statusId = v);
                        _reload();
                      },
                items: [
                  for (final (label, statusId) in bookingStatusFilters)
                    DropdownMenuItem<int?>(
                        value: statusId, child: Text(label)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: TravleTokens.space16),
          Expanded(child: _buildBody(Theme.of(context))),
          const Divider(height: 1),
          PagerBar(
            page: _page,
            pageSize: _pageSize,
            itemCount: _items.length,
            totalCount: _totalCount,
            loading: _loading,
            onPageChanged: _goToPage,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: TravleTokens.space16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        message: 'No bookings in this view',
        hint: 'Bookings will appear here as travelers make them.',
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (context, i) => BookingReviewCard(booking: _items[i]),
    );
  }
}
