import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';

/// Informational note showing the sum of a tour's destinations' entrance fees,
/// **per person**. These are paid on-site at each destination and are **not**
/// charged by Travle. Renders nothing when the total is zero (no stop has a fee),
/// so callers can drop it in unconditionally.
class EntranceFeeNote extends StatelessWidget {
  const EntranceFeeNote({super.key, required this.amountPerPerson});

  final double amountPerPerson;

  @override
  Widget build(BuildContext context) {
    if (amountPerPerson <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entrance fees', style: theme.textTheme.titleSmall),
                const SizedBox(height: TravleTokens.space4),
                Text(
                  'Bring around ${formatPrice(amountPerPerson)} per person for '
                  'entrance fees, paid on-site. Not charged by Travle.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
