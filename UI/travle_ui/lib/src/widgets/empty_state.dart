import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centered placeholder for an empty list/result set (doc 08 §5). Shows an icon,
/// a primary [message], an optional [hint] line, and an optional [action] button
/// (e.g. "Add the first one"). Reads all styling from the theme.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.hint,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String? hint;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TravleTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted),
            const SizedBox(height: TravleTokens.space12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: TravleTokens.space4),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: TravleTokens.space16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
