import 'package:flutter/material.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';

/// A transient card that drops in at the top of the screen when a notification
/// arrives live over SignalR — the mobile equivalent of the desktop toast, sized
/// for a phone (full width, swipe-up to dismiss). Presentational only: the
/// [NotificationToastHost] owns the queue, the auto-dismiss timing, and where the
/// card sits. Tapping it opens the notification; the ✕ (or a swipe up) dismisses.
///
/// Nothing here may depend on an [Overlay]: the host paints above the navigator,
/// which is where the app's overlay lives — so a `Tooltip`, a dropdown menu, or a
/// selectable text field would throw "No Overlay widget found" here.
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
        // Slides down into place from just above its resting position.
        child: Transform.translate(
          offset: Offset(0, (t - 1) * 24),
          child: child,
        ),
      ),
      child: Dismissible(
        key: ValueKey<int>(notification.id),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Material(
          elevation: 6,
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(TravleTokens.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(TravleTokens.radius),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TravleTokens.space12,
                TravleTokens.space12,
                TravleTokens.space4,
                TravleTokens.space12,
              ),
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
                      mainAxisSize: MainAxisSize.min,
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
                    // No `tooltip:` — the host is mounted above the navigator,
                    // so there is no Overlay ancestor for a Tooltip to render
                    // into (see NotificationToastHost). The icon carries the
                    // label for screen readers instead; a phone has no hover
                    // to show a tooltip on anyway.
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      semanticLabel: 'Dismiss',
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
