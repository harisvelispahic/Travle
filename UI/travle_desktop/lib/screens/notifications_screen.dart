import 'dart:async';

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

  /// null = all, false = unread only, true = read only. Mirrors the provider's
  /// filter; kept here too so the segmented control has something to bind to.
  bool? _isReadFilter;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  static const _searchDebounce = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _goToPage(int page) =>
      context.read<NotificationProvider>().loadPage(page);

  // Any filter change re-fetches from page 1 — the old page number belongs to a
  // different result set, so keeping it would land on an arbitrary offset. Both
  // filters are sent together, so narrowing by one never discards the other.
  void _applyFilters() {
    context.read<NotificationProvider>().loadPage(
          1,
          isRead: _isReadFilter,
          text: _searchController.text,
          changeFilter: true,
        );
  }

  void _setReadFilter(bool? isRead) {
    setState(() => _isReadFilter = isRead);
    _applyFilters();
  }

  // Debounced so a query is one request per pause, not one per keystroke.
  void _onSearchChanged(String _) {
    setState(() {}); // repaint the clear button
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _applyFilters);
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {});
    _applyFilters();
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
        // Under the Unread filter every row on screen has just stopped matching
        // it, so refetch rather than leaving a list the filter contradicts.
        if (_isReadFilter != null) _applyFilters();
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
              Padding(
                padding: const EdgeInsets.fromLTRB(TravleTokens.space16,
                    TravleTokens.space12, TravleTokens.space16, TravleTokens.space8),
                child: Wrap(
                  spacing: TravleTokens.space12,
                  runSpacing: TravleTokens.space8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search notifications…',
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Clear',
                                  onPressed: _clearSearch,
                                ),
                        ),
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('All')),
                        ButtonSegment(value: 1, label: Text('Unread')),
                        ButtonSegment(value: 2, label: Text('Read')),
                      ],
                      selected: {
                        _isReadFilter == null ? 0 : (_isReadFilter == false ? 1 : 2)
                      },
                      onSelectionChanged: provider.isLoading
                          ? null
                          : (selection) => _setReadFilter(switch (selection.first) {
                                1 => false,
                                2 => true,
                                _ => null,
                              }),
                    ),
                  ],
                ),
              ),
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
      // Distinguish "nothing here at all" from "nothing matches these filters" —
      // otherwise a filtered-empty list reads as if the feature is broken.
      final searching = _searchController.text.trim().isNotEmpty;
      return ListView(
        children: [
          const SizedBox(height: 120),
          EmptyState(
            icon: searching ? Icons.search_off : Icons.notifications_none,
            message: switch ((searching, _isReadFilter)) {
              (true, _) => 'No notifications match your search',
              (false, false) => 'No unread notifications',
              (false, true) => 'No read notifications',
              _ => 'No notifications yet',
            },
            hint: (searching || _isReadFilter != null)
                ? 'Try a different search, or the All filter.'
                : 'Updates about bookings, reviews and moderation will show up here.',
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
