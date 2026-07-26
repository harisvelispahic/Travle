import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Read-only five-star rating display (doc 08 §5). Renders full / half / empty
/// stars for [value] (0–5) and, when [showValue] is set, the numeric average;
/// an optional [count] (e.g. a review count) renders as "(N)". A subject with no
/// ratings yet ([value] ≤ 0) shows a muted [emptyLabel] instead of a dead row of
/// empty stars.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    this.count,
    this.size = 16,
    this.showValue = true,
    this.emptyLabel = 'Not rated yet',
  });

  /// Average rating in the 0–5 range.
  final double value;

  /// Optional trailing count (reviews) — null hides it.
  final int? count;

  /// Star glyph size; the value/count text scales with the theme.
  final double size;

  /// Whether to append the numeric average after the stars.
  final bool showValue;

  /// Shown (muted) when [value] ≤ 0.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    if (value <= 0) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      );
    }

    final starColor = theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            value >= i
                ? Icons.star
                : value >= i - 0.5
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: starColor,
          ),
        if (showValue) ...[
          const SizedBox(width: TravleTokens.space4),
          Text(value.toStringAsFixed(1), style: theme.textTheme.bodySmall),
        ],
        if (count != null) ...[
          const SizedBox(width: TravleTokens.space4),
          Text(
            '($count)',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
