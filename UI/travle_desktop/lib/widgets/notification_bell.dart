import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';

import '../screens/notification_detail_screen.dart' show NavigateToSection;
import '../screens/notifications_screen.dart';

/// Top-bar bell with a live unread badge for the management app. Reads the unread
/// count from [NotificationProvider] (kept current by REST loads, live pushes, and
/// mark-as-read) and opens the notification centre on tap. [onNavigateToSection] is
/// forwarded to the centre/detail so "go to <section>" can switch the shell.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.onNavigateToSection});

  final NavigateToSection onNavigateToSection;

  @override
  Widget build(BuildContext context) {
    final count =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              NotificationsScreen(onNavigateToSection: onNavigateToSection),
        ),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
