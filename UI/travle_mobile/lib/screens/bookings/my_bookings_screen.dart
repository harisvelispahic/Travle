import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../../widgets/booking_card.dart';
import 'booking_details_screen.dart';

/// The traveler's booking history (`GET /Bookings/mine`): a filterable, newest-first
/// list of their bookings, each opening the detail (master-detail). Status filter
/// chips scope the list server-side by status id.
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

  List<BookingResponse> _bookings = const [];
  bool _loading = true;
  String? _error;
  int? _statusId;

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
      final filter = <String, dynamic>{
        'page': 1,
        'pageSize': 50,
        'includeTotalCount': false,
        if (_statusId != null) 'statusId': _statusId,
      };
      final result = await context.read<BookingProvider>().mine(filter: filter);
      if (!mounted) return;
      setState(() {
        _bookings = result.items;
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
        padding: const EdgeInsets.all(TravleTokens.space16),
        itemCount: _bookings.length,
        itemBuilder: (context, i) {
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
