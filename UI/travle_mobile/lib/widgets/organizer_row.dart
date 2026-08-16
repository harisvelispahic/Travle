import 'package:flutter/material.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/organizer_profile_screen.dart';

/// A tappable "Offered by {organizer}" card that opens the organizer's public
/// profile, so a traveler can see who runs a tour before (or after) booking it.
/// Shared by the tour details and booking details screens.
class OrganizerRow extends StatelessWidget {
  const OrganizerRow({
    super.key,
    required this.organizerId,
    required this.organizerName,
  });

  final int organizerId;
  final String? organizerName;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizerProfileScreen(
          organizerId: organizerId,
          initialName: organizerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.person_outline,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offered by',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: TravleTokens.space4),
                    Text(
                      organizerName ?? 'Organizer',
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
