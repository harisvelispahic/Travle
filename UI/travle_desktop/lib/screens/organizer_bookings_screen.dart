import 'dart:async';

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

/// The organizer's bookings across all their tours (`GET /Bookings/my-tours`),
/// paginated. Search by traveler or tour, filter by status, and split into
/// upcoming / past departures; confirm
/// a booking that is awaiting confirmation, reject it with a mandatory reason, or
/// call off an already-confirmed one (all through the backend state machine).
class OrganizerBookingsScreen extends StatefulWidget {
  const OrganizerBookingsScreen({super.key});

  @override
  State<OrganizerBookingsScreen> createState() =>
      _OrganizerBookingsScreenState();
}

class _OrganizerBookingsScreenState extends State<OrganizerBookingsScreen> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  int? _statusId; // null = all statuses
  _Timeframe _timeframe = _Timeframe.upcoming;
  int _page = 1;
  int? _totalCount;
  bool _loading = true;
  String? _error;
  List<BookingResponse> _items = [];
  final Set<int> _acting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _search = value.trim());
      _reload();
    });
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
      final result = await context.read<BookingProvider>().forMyTours(
        filter: {
          'page': _page,
          'pageSize': _pageSize,
          'includeTotalCount': true,
          if (_search.isNotEmpty) 'text': _search,
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

  Future<void> _confirm(BookingResponse booking) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm booking',
      message:
          'Confirm ${booking.travelerName}\'s booking of ${booking.numberOfPeople} '
          '${booking.numberOfPeople == 1 ? 'seat' : 'seats'} on "${booking.tourName}"?',
      confirmLabel: 'Confirm',
    );
    if (!confirmed) return;
    await _runAction(booking.id, () async {
      await context.read<BookingProvider>().confirm(booking.id);
      return 'Booking confirmed — the traveler has been notified.';
    });
  }

  Future<void> _reject(BookingResponse booking) async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject booking',
      label: 'Reason (sent to the traveler)',
      confirmLabel: 'Reject',
    );
    if (reason == null) return;
    await _runAction(booking.id, () async {
      await context.read<BookingProvider>().reject(booking.id, reason);
      return 'Booking rejected — a full refund is owed.';
    });
  }

  /// Calls off an already-confirmed booking. Unlike a traveler's cancellation this
  /// always refunds in full whatever the notice period, so the dialog says so.
  Future<void> _cancel(BookingResponse booking) async {
    final reason = await showReasonDialog(
      context,
      title: 'Cancel booking',
      label: 'Reason (sent to the traveler)',
      confirmLabel: 'Cancel booking',
      message: 'Cancelling ${booking.travelerName}\'s confirmed booking of '
          '${booking.numberOfPeople} '
          '${booking.numberOfPeople == 1 ? 'seat' : 'seats'} on '
          '"${booking.tourName}" refunds them in full and frees the seats.',
    );
    if (reason == null) return;
    await _runAction(booking.id, () async {
      await context.read<BookingProvider>().organizerCancel(booking.id, reason);
      return 'Booking cancelled — the traveler is being refunded in full.';
    });
  }

  Future<void> _runAction(int id, Future<String> Function() action) async {
    setState(() => _acting.add(id));
    try {
      final message = await action();
      if (!mounted) return;
      AppSnackbars.success(context, message);
      await _load();
    } on ApiClientException catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, e.message);
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: TravleTokens.space12,
                  runSpacing: TravleTokens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search traveler or tour...',
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    _searchController.clear();
                                    _debounce?.cancel();
                                    setState(() => _search = '');
                                    _reload();
                                  },
                                ),
                        ),
                      ),
                    ),
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
                    _StatusFilter(
                      value: _statusId,
                      enabled: !_loading,
                      onChanged: (v) {
                        setState(() => _statusId = v);
                        _reload();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TravleTokens.space12),
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
        hint: 'Bookings on your tours will appear here.',
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: TravleTokens.space12),
      itemBuilder: (context, i) => BookingReviewCard(
        booking: _items[i],
        busy: _acting.contains(_items[i].id),
        onConfirm: () => _confirm(_items[i]),
        onReject: () => _reject(_items[i]),
        onCancel: () => _cancel(_items[i]),
      ),
    );
  }
}

/// Shared status-filter dropdown for the booking management screens.
class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int?>(
      value: value,
      onChanged: enabled ? onChanged : null,
      items: [
        for (final (label, statusId) in bookingStatusFilters)
          DropdownMenuItem<int?>(value: statusId, child: Text(label)),
      ],
    );
  }
}
