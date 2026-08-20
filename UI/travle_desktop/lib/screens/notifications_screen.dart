import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../util/notification_display.dart';
import '../widgets/pager_bar.dart';
import 'notification_detail_screen.dart';

/// The management-app notification centre (organizer/admin). Loads the current
/// user's notifications over REST on open and stays live via [NotificationProvider]'s
/// SignalR feed — a pushed notification prepends here and lights the top-bar bell
/// without a manual refresh. Unread rows are emphasised; a row opens the detail
/// (which marks it read and can jump to the relevant management section).
/// "Mark all as read" (with a confirmation) lives in the app bar.
///
/// Paged, not infinitely scrolled: on a management surface an endless list is easy
/// to get lost in, and every other desktop list already pages. Mobile keeps the
/// infinite scroll — same provider, different read (see [NotificationProvider]).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onNavigateToSection});

  final NavigateToSection onNavigateToSection;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().loadPage(1);
    });
  }

  void _goToPage(int page) =>
      context.read<NotificationProvider>().loadPage(page);

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
        builder: (_) => NotificationDetailScreen(
          notification: notification,
          onNavigateToSection: widget.onNavigateToSection,
        ),
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
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: hasUnread ? 'Mark all as read' : 'No unread notifications',
            onPressed: hasUnread ? _markAllRead : null,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(child: _buildBody(provider)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: TravleTokens.space16),
                child: PagerBar(
                  page: provider.page,
                  pageSize: NotificationProvider.pageSize,
                  itemCount: provider.items.length,
                  totalCount: provider.totalCount,
                  loading: provider.isLoading,
                  onPageChanged: _goToPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    final items = provider.items;

    if (items.isEmpty) {
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.notifications_none,
            message: 'No notifications yet',
            hint: 'Updates about bookings, reviews and moderation will show up here.',
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) => _NotificationTile(
        notification: items[index],
        onTap: () => _open(items[index]),
      ),
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
