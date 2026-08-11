import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';

/// A transient top-right toast shown when a notification arrives live over
/// SignalR — the management app's real-time nudge (organizer booking/cancellation,
/// admin application/moderation events). Presentational only: the [SideNavShell]
/// owns the queue and the auto-dismiss timing. Tapping [onTap] opens the item;
/// the ✕ triggers [onDismiss]. It slides+fades in on first build.
class NotificationToast extends StatelessWidget {
  const NotificationToast({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final NotificationResponse notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notificationIsNegative(notification.type)
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - t) * 24, 0),
          child: child,
        ),
      ),
      child: Material(
        elevation: 6,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(TravleTokens.radius),
          onTap: onTap,
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(TravleTokens.space12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.14),
                  foregroundColor: color,
                  child: Icon(notificationIcon(notification.type), size: 20),
                ),
                const SizedBox(width: TravleTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.text,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TravleTokens.space4),
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
