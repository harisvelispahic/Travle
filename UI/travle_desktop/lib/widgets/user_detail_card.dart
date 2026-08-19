import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/formatting.dart';

/// Read-only presentation of a [UserResponse]: an identity header (avatar, name,
/// username, role chips, suspended badge) over a details grid (email, phone, home
/// city, member-since) and — when the account is suspended — the suspension audit.
///
/// Purely presentational and shared by both the admin user-detail dialog and the
/// signed-in user's own Account screen; each layers its own actions around it.
class UserDetailCard extends StatelessWidget {
  const UserDetailCard({super.key, required this.user});

  final UserResponse user;

  String get _initials {
    final a = user.firstName.trim().isNotEmpty ? user.firstName.trim()[0] : '';
    final b = user.lastName.trim().isNotEmpty ? user.lastName.trim()[0] : '';
    final initials = (a + b).toUpperCase();
    if (initials.isNotEmpty) return initials;
    return user.username.trim().isNotEmpty
        ? user.username.trim()[0].toUpperCase()
        : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName =
        user.fullName.trim().isNotEmpty ? user.fullName : user.username;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(
              // Detail reads may carry the full image; fall back to the thumbnail.
              base64Image: user.profileImage ?? user.profileImageThumbnail,
              radius: 36,
              initials: _initials,
            ),
            const SizedBox(width: TravleTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: TravleTokens.space4),
                  Text(
                    '@${user.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TravleTokens.space8),
                  Wrap(
                    spacing: TravleTokens.space8,
                    runSpacing: TravleTokens.space4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (user.roles.isEmpty)
                        Text(
                          'No roles',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final role in user.roles)
                          Chip(
                            label: Text(role),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      if (user.isSuspended) const _SuspendedBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: TravleTokens.space24),
        _InfoRow(icon: Icons.mail_outline, label: 'Email', value: user.email),
        if (user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty)
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phoneNumber!,
          ),
        if (user.cityName != null && user.cityName!.trim().isNotEmpty)
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Home city',
            value: user.cityName!,
          ),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Member since',
          value: formatDate(deviceLocalTime(user.createdAt)),
        ),
        if (user.isSuspended) ...[
          const SizedBox(height: TravleTokens.space16),
          _SuspensionDetail(user: user),
        ],
      ],
    );
  }
}

class _SuspendedBadge extends StatelessWidget {
  const _SuspendedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TravleTokens.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: color),
          const SizedBox(width: TravleTokens.space4),
          Text(
            'Suspended',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SuspensionDetail extends StatelessWidget {
  const _SuspensionDetail({required this.user});
  final UserResponse user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 18, color: color),
              const SizedBox(width: TravleTokens.space8),
              Text(
                user.suspendedAt != null
                    ? 'Suspended ${formatDateTime(deviceLocalTime(user.suspendedAt!))}'
                    : 'Suspended',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
            ],
          ),
          if (user.suspensionReason != null &&
              user.suspensionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: TravleTokens.space4),
            Text(
              'Reason: ${user.suspensionReason!}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
