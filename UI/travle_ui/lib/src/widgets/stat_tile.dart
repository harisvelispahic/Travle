import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A compact metric card for dashboards and statistics screens: a labelled icon on
/// top, a large [value], and an optional [sub] caption. Set [emphasize] to highlight
/// the headline figure in the brand colour. Reads all styling from the theme (doc 08).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? sub;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: TravleTokens.space8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: TravleTokens.space8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (emphasize
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: emphasize ? theme.colorScheme.primary : null,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: TravleTokens.space4),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
