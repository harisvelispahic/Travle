import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/booking_display.dart';
import '../widgets/booking_review_card.dart';

/// Admin's read-only view of every booking in the system (`GET /Bookings`),
/// filterable by status. Bookings are never edited here — the admin oversees;
/// organizers act. Transitions happen only through the state machine.
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  int? _statusId; // null = all statuses
  bool _loading = true;
  String? _error;
  List<BookingResponse> _items = [];

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
      final result = await context.read<BookingProvider>().get(
        filter: {
          'pageSize': 50,
          if (_statusId != null) 'statusId': _statusId,
        },
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
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
    return Padding(
      padding: const EdgeInsets.all(TravleTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<int?>(
                value: _statusId,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _statusId = v);
                        _load();
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
