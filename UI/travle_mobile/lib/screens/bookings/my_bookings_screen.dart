import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../../widgets/booking_card.dart';
import 'booking_details_screen.dart';

/// The traveler's booking history (`GET /Bookings/mine`): a filterable, newest-first
/// list of their bookings, each opening the detail (master-detail). Status filter
/// chips scope the list server-side by status id, and the list loads further pages
/// as it is scrolled (the mobile default — desktop pages instead).
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  // (label, statusId) — null id means "all".
  static const List<(String, int?)> _filters = [
    ('All', null),
    ('Awaiting payment', 1),
    ('Awaiting confirmation', 2),
    ('Confirmed', 3),
    ('Completed', 4),
    ('Cancelled', 5),
    ('Expired', 6),
  ];

  static const int _pageSize = 10;

  final ScrollController _scrollController = ScrollController();

  final List<BookingResponse> _bookings = [];
  int _page = 1;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int? _statusId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Map<String, dynamic> _filter(int page) => <String, dynamic>{
        'page': page,
        'pageSize': _pageSize,
        'includeTotalCount': true,
        if (_statusId != null) 'statusId': _statusId,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await context.read<BookingProvider>().mine(filter: _filter(1));
      if (!mounted) return;
      setState(() {
        _bookings
          ..clear()
          ..addAll(result.items);
        _totalCount = result.totalCount ?? result.items.length;
        _page = 1;
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

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_bookings.length >= _totalCount) return;

    setState(() => _loadingMore = true);
    try {
      final result = await context
          .read<BookingProvider>()
          .mine(filter: _filter(_page + 1));
      if (!mounted) return;
      setState(() {
        _bookings.addAll(result.items);
        _totalCount = result.totalCount ?? _totalCount;
        _page += 1;
        _loadingMore = false;
      });
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      AppSnackbars.error(context, e.message);
    }
  }

  Future<void> _openDetail(BookingResponse booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(bookingId: booking.id),
      ),
    );
    // The detail may have cancelled the booking — refresh so the list reflects it.
    if (mounted) _load();
  }

  void _selectFilter(int? statusId) {
    if (_statusId == statusId) return;
    setState(() => _statusId = statusId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: SafeArea(
        child: Column(
          children: [
            _FilterBar(
              filters: _filters,
              selected: _statusId,
              onSelect: _selectFilter,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: TravleTokens.space16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.confirmation_number_outlined,
              message: 'No bookings here yet',
              hint: 'Book a tour to see it here.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(TravleTokens.space16),
        // One trailing slot for the "loading the next page" spinner.
        itemCount: _bookings.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _bookings.length) {
            return const Padding(
              padding: EdgeInsets.all(TravleTokens.space16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final booking = _bookings[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: BookingCard(
              booking: booking,
              onTap: () => _openDetail(booking),
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, int?)> filters;
  final int? selected;
  final void Function(int? statusId) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TravleTokens.space16,
          vertical: TravleTokens.space8,
        ),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: TravleTokens.space8),
        itemBuilder: (context, i) {
          final (label, statusId) = filters[i];
          return ChoiceChip(
            label: Text(label),
            selected: selected == statusId,
            onSelected: (_) => onSelect(statusId),
          );
        },
      ),
    );
  }
}
