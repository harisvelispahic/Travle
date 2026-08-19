import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/booking_display.dart';
import '../util/formatting.dart';

/// A traveler's booking in their history list: cover thumbnail, tour name, the
/// departure date/time, party size and total, and a status pill. Tapping opens
/// the booking detail (master-detail). Lists carry thumbnails only (constraint §12).
class BookingCard extends StatelessWidget {
  const BookingCard({super.key, required this.booking, required this.onTap});

  final BookingResponse booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final peopleLabel =
        '${booking.numberOfPeople} ${booking.numberOfPeople == 1 ? 'person' : 'people'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThumbnailImage(
                base64: booking.tourThumbnail,
                width: 84,
                height: 84,
                placeholderIcon: Icons.tour_outlined,
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            booking.tourName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: TravleTokens.space8),
                        StatusPill(
                          label: bookingStatusLabel(booking.status),
                          tone: bookingStatusTone(booking.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: TravleTokens.space8),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Expanded(
                          child: Text(
                            formatEventDate(
                                booking.scheduleStartsAt, booking.timeZoneId),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TravleTokens.space4),
                    Row(
                      children: [
                        Icon(Icons.group_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Text(
                          peopleLabel,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                        const SizedBox(width: TravleTokens.space12),
                        Icon(Icons.payments_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Text(
                          formatPrice(booking.totalAmount),
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
