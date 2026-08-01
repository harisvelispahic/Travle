import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';
import 'notification_detail_screen.dart';

/// The traveler/curator notification centre (doc 07 §9). Loads the current user's
/// notifications over REST on open and stays live via [NotificationProvider]'s
/// SignalR feed — a pushed notification prepends here and lights the app-bar bell
/// without a manual refresh. Unread rows are emphasised; tapping one opens the
/// detail screen (which marks it read and offers a link to the related entity).
/// Pull-to-refresh reloads; scrolling to the end pages in more. "Mark all as read"
/// (with a confirmation) lives in the app bar.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadFirstPage();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark all as read?',
      message: 'Every notification will be marked as read.',
      confirmLabel: 'Mark all read',
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<NotificationProvider>();
    try {
      await provider.markAllRead();
      if (mounted) {
        AppSnackbars.success(context, 'All notifications marked as read.');
      }
    } on ApiClientException catch (e) {
      if (mounted) AppSnackbars.error(context, e.message);
    }
  }

  void _open(NotificationResponse notification) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(notification: notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final hasUnread = provider.unreadCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Always visible; disabled (with a reason) when there's nothing to mark.
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: hasUnread ? 'Mark all as read' : 'No unread notifications',
            onPressed: hasUnread ? _markAllRead : null,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.loadFirstPage,
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    final items = provider.items;

    if (items.isEmpty) {
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      // A scrollable so pull-to-refresh still works on an empty list.
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.notifications_none,
            message: 'No notifications yet',
            hint: 'Updates about your bookings and submissions will show up here.',
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      itemCount: items.length + (provider.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.all(TravleTokens.space16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notification = items[index];
        return _NotificationTile(
          notification: notification,
          onTap: () => _open(notification),
        );
      },
    );
  }
}

/// One notification row: a type icon, the title (bold while unread), a truncated
/// body, a relative timestamp, and an unread dot. The full body is on the detail.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationResponse notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.isRead;
    final color = notificationIsNegative(notification.type)
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return ListTile(
      onTap: onTap,
      isThreeLine: true,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        foregroundColor: color,
        child: Icon(notificationIcon(notification.type)),
      ),
      title: Text(
        notification.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: TravleTokens.space4),
          Text(
            notification.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: TravleTokens.space4),
          Text(
            notificationRelativeTime(notification.createdAt),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: unread
          ? Icon(Icons.circle, size: 10, color: theme.colorScheme.primary)
          : null,
    );
  }
}
