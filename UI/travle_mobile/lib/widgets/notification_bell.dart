import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

import '../screens/notifications_screen.dart';

/// App-bar bell with a live unread badge (doc 07 §8). Reads the unread count from
/// [NotificationProvider] — kept current by REST loads, live pushes, and
/// mark-as-read — and opens the notification centre on tap.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
