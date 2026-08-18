import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';
import 'bookings/booking_details_screen.dart';
import 'destination_details_screen.dart';
import 'tour_details_screen.dart';

/// Full view of a single notification. Opening it marks the notification read.
/// Unlike the list row (which truncates the body), this shows the complete text —
/// so a moderator's rejection reason or a cancellation note is never cut off — plus
/// the type, the exact time, and the read state. When the notification points at a
/// related entity, a button navigates there (a booking → the booking; a destination
/// → the destination). Navigation lives here, so every list row opens this screen
/// first rather than jumping straight to the entity.
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});

  final NotificationResponse notification;

  // RelatedEntityId is a booking id / a destination id / a tour id for these type groups.
  static const Set<String> _bookingTypes = {
    'BookingConfirmed',
    'BookingRejected',
    'BookingCancelled',
    'BookingExpired',
    'BookingReminder',
    'BookingCompleted',
    'PaymentSucceeded',
    'RefundIssued',
    'ScheduleCancelled',
  };
  static const Set<String> _destinationTypes = {
    'DestinationApproved',
    'DestinationRejected',
    'DestinationFeatured',
    'ReviewReceived',
  };
  static const Set<String> _tourTypes = {
    'TourUpdated',
  };

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Viewing the detail counts as reading it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().markRead(widget.notification.id);
      }
    });
  }

  String get _type => widget.notification.type;

  bool get _hasRelated =>
      widget.notification.relatedEntityId != null &&
      (NotificationDetailScreen._bookingTypes.contains(_type) ||
          NotificationDetailScreen._destinationTypes.contains(_type) ||
          NotificationDetailScreen._tourTypes.contains(_type));

  String get _relatedLabel {
    if (NotificationDetailScreen._bookingTypes.contains(_type)) return 'View booking';
    if (NotificationDetailScreen._tourTypes.contains(_type)) return 'View tour';
    return 'View destination';
  }

  void _openRelated() {
    final id = widget.notification.relatedEntityId;
    if (id == null) return;
    final Widget target;
    if (NotificationDetailScreen._bookingTypes.contains(_type)) {
      target = BookingDetailsScreen(bookingId: id);
    } else if (NotificationDetailScreen._tourTypes.contains(_type)) {
      target = TourDetailsScreen(tourId: id);
    } else {
      target = DestinationDetailsScreen(destinationId: id);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notification = widget.notification;
    final color = notificationIsNegative(_type)
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: ListView(
        padding: const EdgeInsets.all(TravleTokens.space16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: Icon(notificationIcon(_type)),
              ),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Text(
                  notificationTypeLabel(_type),
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
          if (_hasRelated) ...[
            const SizedBox(height: TravleTokens.space24),
            FilledButton.icon(
              onPressed: _openRelated,
              icon: const Icon(Icons.open_in_new),
              label: Text(_relatedLabel),
            ),
          ],
        ],
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
