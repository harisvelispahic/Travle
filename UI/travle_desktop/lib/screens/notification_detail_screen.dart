import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';

/// Callback that switches the management shell to a side-nav section by key.
typedef NavigateToSection = void Function(String sectionKey);

/// Full view of a single notification on the management app. Opening it marks the
/// notification read and shows the complete, untruncated body (so a cancellation
/// note or review text is never cut off), the type, the exact local time, and the
/// read state. When the notification relates to something actionable, a button
/// jumps to the relevant management section (Tour Bookings, Tour Reviews, Role
/// Requests, Destinations) — desktop screens are shell-embedded lists rather than
/// pushable detail pages, so this navigates to the section, not a single record.
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.notification,
    required this.onNavigateToSection,
  });

  final NotificationResponse notification;
  final NavigateToSection onNavigateToSection;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().markRead(widget.notification.id);
      }
    });
  }

  /// The side-nav section this notification's type is actionable in, if any.
  static String? _sectionFor(String type) {
    switch (type) {
      case 'BookingPlaced':
      case 'BookingCancelled':
        return 'tourBookings';
      case 'ReviewReceived':
        return 'myTourReviews';
      case 'RoleApplicationSubmitted':
        return 'roleRequests';
      case 'DestinationSubmitted':
        return 'destinations';
      default:
        return null;
    }
  }

  static String _sectionLabel(String key) {
    switch (key) {
      case 'tourBookings':
        return 'Tour Bookings';
      case 'myTourReviews':
        return 'Tour Reviews';
      case 'roleRequests':
        return 'Role Requests';
      case 'destinations':
        return 'Destinations';
      default:
        return 'section';
    }
  }

  void _goToSection(String key) {
    widget.onNavigateToSection(key);
    // Close the detail + centre overlays so the shell shows the new section.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notification = widget.notification;
    final type = notification.type;
    final color = notificationIsNegative(type)
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final section = _sectionFor(type);

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(TravleTokens.space24),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: 0.14),
                    foregroundColor: color,
                    child: Icon(notificationIcon(type)),
                  ),
                  const SizedBox(width: TravleTokens.space12),
                  Expanded(
                    child: Text(
                      notificationTypeLabel(type),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TravleTokens.space16),
              Text(notification.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: TravleTokens.space12),
              SelectableText(
                notification.text,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: TravleTokens.space24),
              const Divider(height: 1),
              _MetaRow(
                icon: Icons.schedule,
                label: 'Received',
                value: notificationFullTime(notification.createdAt),
              ),
              _MetaRow(
                icon: notification.isRead
                    ? Icons.mark_email_read_outlined
                    : Icons.mark_email_unread_outlined,
                label: 'Status',
                value: notification.isRead ? 'Read' : 'Unread',
              ),
              if (section != null) ...[
                const SizedBox(height: TravleTokens.space24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _goToSection(section),
                    icon: const Icon(Icons.open_in_new),
                    label: Text('Go to ${_sectionLabel(section)}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled meta line ("Received", "Status") under the notification body.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TravleTokens.space12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: TravleTokens.space12),
          Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
