import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../../util/booking_display.dart';
import '../../util/formatting.dart';
import '../tour_details_screen.dart';

/// The detail half of the traveler's booking master-detail. Shows the full
/// booking (tour, schedule, party, total, status, audit) and the actions the
/// current state permits: paying a held booking (stub until Stripe lands in
/// Phase 6) and cancelling a Pending/Confirmed booking with the applicable
/// refund-tier summary shown first.
class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  BookingResponse? _booking;
  bool _loading = true;
  bool _busy = false;
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
      final booking =
          await context.read<BookingProvider>().getDetail(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
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

  void _openTour() {
    final booking = _booking;
    if (booking == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TourDetailsScreen(
          tourId: booking.tourId,
          initialName: booking.tourName,
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    final booking = _booking!;
    final reason = await _promptCancel(booking);
    if (reason == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await context
          .read<BookingProvider>()
          .cancel(booking.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _busy = false;
      });
      AppSnackbars.success(context, 'Your booking has been cancelled.');
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackbars.error(context, e.message);
    }
  }

  // Returns the (possibly empty) reason when confirmed, or null when dismissed.
  Future<String?> _promptCancel(BookingResponse booking) {
    final controller = TextEditingController();
    final pct = booking.cancellationRefundPercentage;
    final refundLine = pct == null
        ? 'A refund will be calculated from the cancellation policy.'
        : pct > 0
            ? "You'll be refunded $pct% of ${formatPrice(booking.totalAmount)} "
                '(${formatPrice(booking.totalAmount * pct / 100)}).'
            : 'This cancellation is not eligible for a refund '
                '(less than 1 hour before departure).';

    return showDialog<String>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Cancel booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(refundLine),
              const SizedBox(height: TravleTokens.space16),
              TextField(
                controller: controller,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pay() async {
    // Stub: Stripe PaymentSheet arrives in Phase 6. The booking is already holding
    // seats; here we only explain what will happen so the flow is honest.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment coming soon'),
        content: const Text(
          'Online payment (Stripe) will be available in the next update. Your '
          'seats are held for 15 minutes from checkout; if payment is not '
          'completed in time, the hold is released automatically.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: SafeArea(child: _buildBody()),
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

    final booking = _booking!;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(TravleTokens.space16),
      children: [
        _Header(booking: booking, onOpenTour: _openTour),
        const SizedBox(height: TravleTokens.space24),
        _DetailCard(booking: booking),
        if (booking.isPaymentInProgress && booking.expiresAt != null) ...[
          const SizedBox(height: TravleTokens.space16),
          _HoldNotice(expiresAt: booking.expiresAt!),
        ],
        if (booking.rejectionReason != null &&
            booking.rejectionReason!.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space16),
          _ReasonNotice(
            icon: Icons.block_outlined,
            title: 'Rejected by the organizer',
            text: booking.rejectionReason!,
          ),
        ],
        if (booking.cancellationReason != null &&
            booking.cancellationReason!.isNotEmpty) ...[
          const SizedBox(height: TravleTokens.space16),
          _ReasonNotice(
            icon: Icons.info_outline,
            title: 'Cancellation reason',
            text: booking.cancellationReason!,
          ),
        ],
        const SizedBox(height: TravleTokens.space24),
        if (booking.canCancel && booking.cancellationRefundPercentage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TravleTokens.space8),
            child: Row(
              children: [
                Icon(Icons.savings_outlined,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: TravleTokens.space8),
                Expanded(
                  child: Text(
                    'Cancel now → ${booking.cancellationRefundPercentage}% refund.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ..._actions(booking),
      ],
    );
  }

  List<Widget> _actions(BookingResponse booking) {
    final actions = <Widget>[];
    if (booking.canPay) {
      actions.add(
        FilledButton.icon(
          onPressed: _busy ? null : _pay,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Pay now'),
        ),
      );
    }
    if (booking.canCancel) {
      if (actions.isNotEmpty) {
        actions.add(const SizedBox(height: TravleTokens.space8));
      }
      actions.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel booking'),
        ),
      );
    }
    return actions;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking, required this.onOpenTour});

  final BookingResponse booking;
  final VoidCallback onOpenTour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThumbnailImage(
          base64: booking.tourThumbnail,
          width: 96,
          height: 96,
          placeholderIcon: Icons.tour_outlined,
        ),
        const SizedBox(width: TravleTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onOpenTour,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(booking.tourName,
                          style: theme.textTheme.titleLarge),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
              const SizedBox(height: TravleTokens.space8),
              StatusPill(
                label: bookingStatusLabel(booking.status),
                tone: bookingStatusTone(booking.status),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.booking});

  final BookingResponse booking;

  @override
  Widget build(BuildContext context) {
    final peopleLabel =
        '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          children: [
            _Row(
              icon: Icons.event_outlined,
              label: 'Departure',
              value: formatScheduleRange(
                  booking.scheduleStartsAt, booking.scheduleEndsAt),
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: Icons.group_outlined,
              label: 'Party',
              value: peopleLabel,
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: Icons.payments_outlined,
              label: 'Total',
              value: formatPrice(booking.totalAmount),
            ),
            const Divider(height: TravleTokens.space24),
            _Row(
              icon: booking.isPaid
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              label: 'Payment',
              value: booking.isPaid ? 'Paid' : 'Not paid',
            ),
            if (booking.confirmedByName != null) ...[
              const Divider(height: TravleTokens.space24),
              _Row(
                icon: Icons.verified_outlined,
                label: 'Confirmed by',
                value: booking.confirmedByName!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 18, color: muted),
        const SizedBox(width: TravleTokens.space12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        const SizedBox(width: TravleTokens.space12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// A live count-down of the 15-minute payment hold. Ticks once a second toward
/// [expiresAt] and stops at 00:00 (never goes negative). The remaining time is
/// computed in UTC on both sides (see [asUtc]) so it is correct on any device
/// time zone, even though the app otherwise shows server times as wall-clock.
class _HoldNotice extends StatefulWidget {
  const _HoldNotice({required this.expiresAt});

  final DateTime expiresAt;

  @override
  State<_HoldNotice> createState() => _HoldNoticeState();
}

class _HoldNoticeState extends State<_HoldNotice> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _timeLeft();
    if (_remaining > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = _timeLeft();
        if (!mounted) return;
        setState(() => _remaining = left);
        if (left <= Duration.zero) _timer?.cancel();
      });
    }
  }

  Duration _timeLeft() {
    final diff = asUtc(widget.expiresAt).difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = _remaining <= Duration.zero;
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_outlined,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seats held', style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                Text(
                  '$mm:$ss',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: expired
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: TravleTokens.space4),
                Text(
                  expired
                      ? 'This hold has expired — the seats may have been released.'
                      : 'Complete payment before the timer runs out or the seats are released.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonNotice extends StatelessWidget {
  const _ReasonNotice({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
