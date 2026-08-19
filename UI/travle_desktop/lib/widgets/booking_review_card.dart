import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/booking_display.dart';
import '../util/formatting.dart';

/// One booking in the management lists — the traveler, the tour + departure,
/// party size and total, the status, and any decision/cancellation audit. When
/// [onConfirm]/[onReject] are provided (the organizer view) and the booking is
/// still awaiting confirmation, it renders Confirm / Reject actions; otherwise it
/// is read-only (the admin all-bookings view).
class BookingReviewCard extends StatelessWidget {
  const BookingReviewCard({
    super.key,
    required this.booking,
    this.busy = false,
    this.onConfirm,
    this.onReject,
  });

  final BookingResponse booking;
  final bool busy;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  bool get _showActions => booking.isPending && onConfirm != null && onReject != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final peopleLabel =
        '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.tourName, style: theme.textTheme.titleMedium),
                      const SizedBox(height: TravleTokens.space4),
                      Text(
                        '${booking.travelerName} · @${booking.travelerUsername}',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: bookingStatusLabel(booking.status),
                  tone: bookingStatusTone(booking.status),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space12),
            Wrap(
              spacing: TravleTokens.space16,
              runSpacing: TravleTokens.space4,
              children: [
                _Meta(
                  icon: Icons.event_outlined,
                  label: formatEventScheduleRange(booking.scheduleStartsAt,
                      booking.scheduleEndsAt, booking.timeZoneId),
                ),
                _Meta(icon: Icons.group_outlined, label: peopleLabel),
                _Meta(
                    icon: Icons.payments_outlined,
                    label: formatPrice(booking.totalAmount)),
                _Meta(
                  icon: booking.isPaid
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  label: booking.isPaid ? 'Paid' : 'Not paid',
                ),
              ],
            ),
            if (booking.confirmedByName != null) ...[
              const SizedBox(height: TravleTokens.space8),
              _Meta(
                icon: Icons.verified_outlined,
                label: 'Confirmed by ${booking.confirmedByName}',
              ),
            ],
            if (booking.rejectionReason != null &&
                booking.rejectionReason!.trim().isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space8),
              _ReasonLine(label: 'Rejected', text: booking.rejectionReason!),
            ],
            if (booking.cancellationReason != null &&
                booking.cancellationReason!.trim().isNotEmpty) ...[
              const SizedBox(height: TravleTokens.space8),
              _ReasonLine(
                  label: 'Cancellation reason',
                  text: booking.cancellationReason!),
            ],
            if (_showActions) ...[
              const SizedBox(height: TravleTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(right: TravleTokens.space16),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  FilledButton.icon(
                    onPressed: busy ? null : onConfirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: TravleTokens.space4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _ReasonLine extends StatelessWidget {
  const _ReasonLine({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
