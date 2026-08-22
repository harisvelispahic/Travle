import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../screens/notification_detail_screen.dart';
import '../widgets/notification_toast.dart';

/// The app's topmost layer: live notification toasts painted **above the whole
/// navigator**, so a push that lands while the user is deep inside a pushed route
/// (a destination, the booking flow, the notification centre) is still seen.
///
/// It is mounted from `MaterialApp.builder`, which is the one place that sits
/// above every route. Hosting the toasts inside a screen — or inside the shell,
/// the way the desktop `SideNavShell` does — would bury them under any route
/// pushed on top, and on mobile the user is on a pushed route most of the time.
/// The only surfaces this cannot cover are the ones Flutter does not draw: the
/// native Stripe PaymentSheet and system dialogs.
///
/// The price of sitting up here is that there is **no [Overlay] in scope** — the
/// app's overlay belongs to the navigator below us — so a toast must not use a
/// widget that needs one (a `Tooltip`, a dropdown menu, a selectable text field);
/// those throw "No Overlay widget found" and Flutter substitutes a 100000px-wide
/// error box. Keep the card to plain Material.
///
/// The toast is only the transient nudge — the notification row and the bell's
/// unread badge (both already updated by [NotificationProvider] by the time the
/// push arrives here) stay the durable record. Session-affecting pushes are left
/// to the [AuthGate], which answers them with a refresh or a re-login dialog.
class NotificationToastHost extends StatefulWidget {
  const NotificationToastHost({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The app's navigator. The host lives above it, so it has no [Navigator]
  /// ancestor of its own to push a tapped notification's detail screen onto.
  final GlobalKey<NavigatorState> navigatorKey;

  /// The app itself — the navigator handed to `MaterialApp.builder`.
  final Widget child;

  @override
  State<NotificationToastHost> createState() => _NotificationToastHostState();
}

class _NotificationToastHostState extends State<NotificationToastHost> {
  StreamSubscription<NotificationResponse>? _pushSub;
  final List<_Toast> _toasts = <_Toast>[];
  final Map<Key, Timer> _toastTimers = <Key, Timer>{};

  /// A phone shows few at once; older ones drop off the bottom of the stack.
  static const int _maxToasts = 3;
  static const Duration _toastDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pushSub = context.read<NotificationProvider>().pushes.listen(_onPush);
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Unlike a screen, this host never unmounts, so a sign-out has to drop the
    // queue explicitly: a card from the ended session would otherwise sit over
    // the login screen for its remaining seconds, and tapping it would open a
    // detail screen the (now gone) token cannot load. No setState — a build
    // always follows didChangeDependencies.
    final signedIn = Provider.of<AuthProvider>(context).isAuthenticated;
    if (!signedIn && _toasts.isNotEmpty) {
      for (final timer in _toastTimers.values) {
        timer.cancel();
      }
      _toastTimers.clear();
      _toasts.clear();
    }
  }

  void _onPush(NotificationResponse notification) {
    if (!mounted) return;
    // Pushes about our own account (suspension, a role grant/revoke) are handled
    // by the AuthGate — don't also surface them as a toast.
    if (sessionAffectingNotificationTypes.contains(notification.type)) return;
    final toast = _Toast(notification);
    setState(() {
      _toasts.insert(0, toast);
      if (_toasts.length > _maxToasts) {
        final removed = _toasts.removeLast();
        _toastTimers.remove(removed.key)?.cancel();
      }
    });
    _toastTimers[toast.key] = Timer(
      _toastDuration,
      () => _dismissToast(toast.key),
    );
  }

  void _dismissToast(Key key) {
    _toastTimers.remove(key)?.cancel();
    final index = _toasts.indexWhere((t) => t.key == key);
    if (index == -1) return;
    if (mounted) {
      setState(() => _toasts.removeAt(index));
    } else {
      _toasts.removeAt(index);
    }
  }

  void _openToast(_Toast toast) {
    _dismissToast(toast.key);
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationDetailScreen(notification: toast.notification),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Every child is positioned on purpose: a Stack whose children are all
    // positioned takes the largest size its constraints allow, which is exactly
    // the full window the app needs. The toast column is laid out below the
    // status bar and hit-tests only where it actually paints.
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_toasts.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + TravleTokens.space8,
            left: TravleTokens.space12,
            right: TravleTokens.space12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final toast in _toasts)
                  Padding(
                    key: toast.key,
                    padding: const EdgeInsets.only(bottom: TravleTokens.space8),
                    child: NotificationToast(
                      notification: toast.notification,
                      onTap: () => _openToast(toast),
                      onDismiss: () => _dismissToast(toast.key),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One live notification toast in the host's queue; [key] gives it a stable
/// identity across rebuilds (and keys its auto-dismiss timer).
class _Toast {
  _Toast(this.notification) : key = UniqueKey();

  final NotificationResponse notification;
  final Key key;
}
