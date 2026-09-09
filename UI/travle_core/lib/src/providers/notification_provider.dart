import 'dart:async';

import '../models/notification_response.dart';
import '../network/base_provider.dart';
import '../realtime/notification_realtime_service.dart';

/// The current user's notifications: the REST list/badge/mark-read endpoints
/// (`/Notifications`, inherited from [BaseProvider]) plus the live SignalR feed
/// ([NotificationRealtimeService]). Shared by both apps — mobile and desktop
/// consume it identically; each only renders its own bell + centre.
///
/// Lifecycle is driven by auth: [syncAuth] connects the socket and primes the
/// unread badge on sign-in, and tears everything down on sign-out. Wire it with
/// a `ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>` so those
/// transitions fire automatically.
class NotificationProvider extends BaseProvider<NotificationResponse> {
  NotificationProvider() : super('Notifications') {
    _realtime = NotificationRealtimeService(onNotification: _onPushed);
  }

  /// Rows per fetch — one infinite-scroll chunk on mobile, one page on desktop.
  static const int pageSize = 30;

  late final NotificationRealtimeService _realtime;

  // Broadcasts each live push so an app can react to specific types beyond the
  // list/badge (e.g. the mobile shell force-logs-out on a role-grant push).
  final StreamController<NotificationResponse> _pushes =
      StreamController<NotificationResponse>.broadcast();

  final List<NotificationResponse> _items = <NotificationResponse>[];
  int _unreadCount = 0;
  bool _loading = false;
  bool _authConnected = false;
  int _page = 1;
  int? _totalCount;
  bool _hasMore = true;

  /// Read/unread filter applied to [loadPage]: null = all, true = read only,
  /// false = unread only. Held here rather than in the screen so paging keeps
  /// the filter, and so a live push can tell whether it belongs in the current
  /// view. Mobile never sets it and is unaffected.
  bool? _isReadFilter;

  /// Free-text query applied to [loadPage] (title and body), or null for none.
  /// Held alongside the read filter for the same reasons.
  String? _textFilter;

  /// The loaded notifications, newest first.
  List<NotificationResponse> get items => List.unmodifiable(_items);

  /// Unread count for the app-bar bell badge (kept live by pushes + mark-read).
  int get unreadCount => _unreadCount;

  bool get isLoading => _loading;
  bool get hasMore => _hasMore;

  /// The page currently loaded — meaningful for the desktop pager; on mobile the
  /// list accumulates and this is simply the last chunk fetched.
  int get page => _page;

  /// Total matching rows as of the last [loadPage] (null until one lands).
  int? get totalCount => _totalCount;

  /// The active read/unread filter (null = all).
  bool? get isReadFilter => _isReadFilter;

  /// The active free-text query (null when the list is unfiltered by text).
  String? get textFilter => _textFilter;

  /// Whether any filter is narrowing the list — lets a screen explain an empty
  /// result rather than implying there is nothing at all.
  bool get isFiltered => _isReadFilter != null || _textFilter != null;
  bool get isConnected => _realtime.isConnected;

  /// Fires for every live (SignalR) push, for app-level reactions to specific
  /// notification types. The list/badge are already updated by the time it fires.
  Stream<NotificationResponse> get pushes => _pushes.stream;

  @override
  NotificationResponse fromJson(Map<String, dynamic> json) =>
      NotificationResponse.fromJson(json);

  /// Called by the proxy provider on every auth change; acts only on the
  /// sign-in / sign-out transition (idempotent otherwise).
  void syncAuth(bool isAuthenticated) {
    if (isAuthenticated && !_authConnected) {
      _authConnected = true;
      unawaited(_realtime.connect());
      unawaited(refreshUnreadCount());
    } else if (!isAuthenticated && _authConnected) {
      _authConnected = false;
      unawaited(_realtime.disconnect());
      _items.clear();
      _unreadCount = 0;
      _page = 1;
      _totalCount = null;
      _hasMore = true;
      notifyListeners();
    }
  }

  /// Ensures the live socket is up (a cheap retry point when opening the centre).
  Future<void> ensureConnected() => _realtime.connect();

  Future<void> refreshUnreadCount() async {
    try {
      final json = await getAction('unread-count') as Map<String, dynamic>?;
      _unreadCount = (json?['count'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {
      // Non-fatal: the badge just keeps its last value.
    }
  }

  /// Loads (or reloads) the first page and refreshes the badge.
  Future<void> loadFirstPage() => loadPage(1);

  /// Loads one page, **replacing** the list rather than appending to it.
  ///
  /// This is the desktop centre's model — a management surface pages the way its
  /// tables do, so an admin can walk a long history without an ever-growing list.
  /// Mobile calls [loadFirstPage] once and then [loadMore] to accumulate.
  /// Set [changeFilter] to apply [isRead] and [text] (either may be null to
  /// clear that one); leave it off to keep whatever is already applied, which is
  /// what the pager does when moving between pages.
  Future<void> loadPage(
    int page, {
    bool? isRead,
    String? text,
    bool changeFilter = false,
  }) async {
    if (changeFilter) {
      _isReadFilter = isRead;
      final trimmed = text?.trim();
      _textFilter = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    }
    _loading = true;
    notifyListeners();
    try {
      final result = await get(filter: {
        'page': page,
        'pageSize': pageSize,
        'includeTotalCount': true,
        if (_isReadFilter != null) 'isRead': _isReadFilter,
        if (_textFilter != null) 'text': _textFilter,
      });
      _items
        ..clear()
        ..addAll(result.items);
      _page = page;
      _totalCount = result.totalCount;
      _hasMore = result.items.length >= pageSize;
      await refreshUnreadCount();
    } finally {
      _loading = false;
      notifyListeners();
    }
    unawaited(ensureConnected());
  }

  /// Appends the next page (infinite scroll); no-op while loading or at the end.
  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final result = await get(filter: {'page': next, 'pageSize': pageSize});
      _items.addAll(result.items);
      _page = next;
      _hasMore = result.items.length >= pageSize;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Marks one notification read (optimistic; server-confirmed).
  Future<void> markRead(int id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].isRead) return;

    _items[index] = _items[index].copyWith(isRead: true, readAt: DateTime.now());
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await putAction('$id/read');
    } catch (_) {
      // Reconcile with the server if the write didn't land.
      await refreshUnreadCount();
    }
  }

  /// Marks every notification read.
  Future<void> markAllRead() async {
    if (_unreadCount == 0 && _items.every((n) => n.isRead)) return;
    await putAction('read-all');
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true, readAt: DateTime.now());
      }
    }
    _unreadCount = 0;
    notifyListeners();
  }

  void _onPushed(NotificationResponse notification) {
    // Guard against a duplicate if the same row also arrives via a REST refresh.
    _items.removeWhere((n) => n.id == notification.id);

    // A pushed notification belongs in the list only when the current view would
    // have fetched it: it is unread by definition, so it never belongs under a
    // "Read" filter, and it is only prepended under a text query when it
    // actually matches — otherwise the push would put a row on screen that the
    // filters say isn't there. The badge and the push stream fire either way.
    if (_isReadFilter != true && _matchesTextFilter(notification)) {
      _items.insert(0, notification);
    }
    if (!notification.isRead) _unreadCount++;
    notifyListeners();
    _pushes.add(notification);
  }

  // Mirrors the server's contains-match over title and body, case-insensitively.
  // Only ever used to decide whether a live push joins an already-filtered list;
  // the authoritative filtering is the query the server ran.
  bool _matchesTextFilter(NotificationResponse notification) {
    final term = _textFilter?.toLowerCase();
    if (term == null) return true;
    return notification.title.toLowerCase().contains(term) ||
        notification.text.toLowerCase().contains(term);
  }

  @override
  void dispose() {
    unawaited(_realtime.disconnect());
    unawaited(_pushes.close());
    super.dispose();
  }
}
