import 'package:flutter/material.dart';

/// Temporary placeholder for tabs/screens not yet implemented. Replaced by real
/// content in later phases (Home §Phase 8, Search §Phase 3, Favorites §Phase 7).
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.title, this.icon = Icons.construction});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Coming soon', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
