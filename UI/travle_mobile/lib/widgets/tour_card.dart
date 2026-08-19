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
      return 'Next: ${formatEventDate(tour.nextDepartureAt!, tour.timeZoneId)}';
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
                    // Wrap (not Row) so price + duration reflow onto a second line
                    // on tight widths instead of overflowing horizontally.
                    Wrap(
                      spacing: TravleTokens.space12,
                      runSpacing: TravleTokens.space4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaChip(
                          icon: Icons.payments_outlined,
                          label: '${formatPrice(tour.pricePerPerson)} / person',
                        ),
                        _MetaChip(
                          icon: Icons.schedule_outlined,
                          label: formatDuration(tour.durationMinutes),
                        ),
                      ],
                    ),
                    const SizedBox(height: TravleTokens.space4),
                    Row(
                      children: [
                        Icon(Icons.event_outlined, size: 14, color: muted),
                        const SizedBox(width: TravleTokens.space4),
                        Expanded(
                          child: Text(
                            _departure,
                            style:
                                theme.textTheme.bodySmall?.copyWith(color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

/// A compact icon + label metric used inside the card's [Wrap], sized to its
/// content so several can flow onto one or more lines without overflowing.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: muted),
        const SizedBox(width: TravleTokens.space4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
