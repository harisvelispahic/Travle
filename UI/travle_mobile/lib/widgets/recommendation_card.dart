import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

/// A rich destination card for the recommender surfaces — the Home "Recommended
/// for you" carousel and the details-screen "Similar destinations" strip. Shows a
/// cover thumbnail with a rating badge, the name and location, and (when
/// [showReason] is set) the recommender's explanation chip.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.item,
    required this.onTap,
    this.showReason = true,
    this.width = 260,
  });

  final RecommendationItem item;
  final VoidCallback onTap;

  /// Whether to render the "why" chip. Hidden for cold-start lists, where every
  /// reason is the identical popularity label and the section title already says so.
  final bool showReason;

  final double width;

  String get _location => [
        item.destination.cityName,
        item.destination.regionName,
      ].where((p) => p != null && p.isNotEmpty).cast<String>().join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destination = item.destination;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ThumbnailImage(
                    base64: destination.primaryThumbnail,
                    width: width,
                    height: 140,
                    radius: 0,
                    placeholderIcon: Icons.photo_outlined,
                  ),
                  Positioned(
                    top: TravleTokens.space8,
                    right: TravleTokens.space8,
                    child: _RatingBadge(value: destination.averageRating),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(TravleTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      destination.name,
                      style: theme.textTheme.titleSmall,
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
                                  color: theme.colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showReason) ...[
                      const SizedBox(height: TravleTokens.space8),
                      _ReasonChip(reason: item.reason),
                    ],
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

/// A compact rating badge overlaid on the cover image (star + one-decimal value,
/// or an em dash when a destination has no reviews yet).
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: TravleTokens.space8, vertical: TravleTokens.space4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
          const SizedBox(width: TravleTokens.space4),
          Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The recommender's "why" chip — a soft pill with a sparkle and the explanation
/// text (e.g. "Because you're interested in Nature").
class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: TravleTokens.space8, vertical: TravleTokens.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 14, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: TravleTokens.space4),
          Flexible(
            child: Text(
              reason,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
