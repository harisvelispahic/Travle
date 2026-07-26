import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';

/// Browse card for a tour in a vertical list (the "tours visiting here" section):
/// cover thumbnail, name, type, price per person, duration, and the next
/// departure. Tapping opens the tour details. Lists carry thumbnails only
/// (constraint §12).
class TourCard extends StatelessWidget {
  const TourCard({super.key, required this.tour, required this.onTap});

  final TourResponse tour;
  final VoidCallback onTap;

  String get _departure {
    if (tour.nextDepartureAt != null) {
      return 'Next: ${formatDate(tour.nextDepartureAt!)}';
    }
    return 'No upcoming dates';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
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
                base64: tour.primaryThumbnail,
                width: 84,
                height: 84,
                placeholderIcon: Icons.tour_outlined,
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tour.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tour.tourTypeName != null) ...[
                      const SizedBox(height: TravleTokens.space4),
                      Text(
                        tour.tourTypeName!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                    const SizedBox(height: TravleTokens.space8),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Text(
                          '${formatPrice(tour.pricePerPerson)} / person',
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                        const SizedBox(width: TravleTokens.space12),
                        Icon(Icons.schedule_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Text(
                          formatDuration(tour.durationMinutes),
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: TravleTokens.space4),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Text(
                          _departure,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
