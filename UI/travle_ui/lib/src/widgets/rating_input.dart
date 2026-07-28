import 'package:flutter/material.dart';

/// Interactive 1–5 star selector for composing a review — the input counterpart of
/// [RatingStars]. Tapping a star sets the rating and reports it through [onChanged];
/// [value] 0 means "not rated yet" (all stars outlined).
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 40,
  });

  /// Current selection, 0–5 (0 = nothing selected).
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            iconSize: size,
            color: color,
            onPressed: () => onChanged(i),
            tooltip: '$i ${i == 1 ? 'star' : 'stars'}',
            icon: Icon(i <= value ? Icons.star : Icons.star_border),
          ),
      ],
    );
  }
}
