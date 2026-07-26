import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// Browse card for a destination in a vertical list (search results, favorites):
/// list thumbnail, name, city · region, category, and rating. Tapping opens the
/// details screen. Lists carry thumbnails only (constraint §12) — the full image
/// gallery loads only on the details screen.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
  });

  final DestinationResponse destination;
  final VoidCallback onTap;

  String get _location => [destination.cityName, destination.regionName]
      .where((p) => p != null && p.isNotEmpty)
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                base64: destination.primaryThumbnail,
                width: 84,
                height: 84,
                placeholderIcon: Icons.photo_outlined,
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_location.isNotEmpty) ...[
                      const SizedBox(height: TravleTokens.space4),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: TravleTokens.space4),
                          Expanded(
                            child: Text(
                              _location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (destination.categoryName != null &&
                        destination.categoryName!.isNotEmpty) ...[
                      const SizedBox(height: TravleTokens.space8),
                      Text(
                        destination.categoryName!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                    const SizedBox(height: TravleTokens.space8),
                    RatingStars(value: destination.averageRating, size: 15),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
