import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../layouts/side_nav_shell.dart';
import '../screens/auth/login_screen.dart';

/// Root switch: shows the management shell only for an authenticated account
/// that holds a desktop role (Organizer/Admin); otherwise the login screen. A
/// traveler/curator who signs in here is treated as not-allowed — [LoginScreen]
/// clears that session and explains why.
///
/// It also owns the app-wide **session-ended** handling: a server-side auth change
/// (suspension, a role grant/revoke) rolls the account's security stamp, so the
/// current token is rejected on its next use. On the matching live push — or on an
/// involuntary token loss surfaced by [BaseProvider] — it tries a silent refresh
/// (seamless when the refresh token was kept, e.g. an admin changing their own
/// non-admin role); if that fails, it routes to login and explains why. Being the
/// stable root (it never unmounts), it's the right place for both.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<NotificationResponse>? _pushSub;
  bool _sessionEndedShowing = false;

  @override
  void initState() {
    super.initState();
    AuthProvider.onSessionEnded = _handleSessionEnded;
    _pushSub = context.read<NotificationProvider>().pushes.listen(_onPush);
  }

  @override
  void dispose() {
    if (AuthProvider.onSessionEnded == _handleSessionEnded) {
      AuthProvider.onSessionEnded = null;
    }
    _pushSub?.cancel();
    super.dispose();
  }

  Future<void> _onPush(NotificationResponse notification) async {
    if (!sessionAffectingNotificationTypes.contains(notification.type)) return;
    // Our access token's stamp was just rolled. A silent refresh succeeds only if the
    // refresh token was kept (seamless — new permissions apply); otherwise end the session.
    final refreshed = await context.read<AuthProvider>().tryRefresh();
    if (refreshed || !mounted) return;
    await _handleSessionEnded(
        sessionEndedReason(notification.type, notification.text));
  }

  Future<void> _handleSessionEnded(String message) async {
    if (_sessionEndedShowing || !mounted) return;
    _sessionEndedShowing = true;
    // Drop any pushed routes/dialogs so the login screen (this gate's unauthenticated state) shows.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await showSessionEndedDialog(context, message: message);
    _sessionEndedShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) return const AppSplash();
    final allowed = auth.isAuthenticated && auth.hasAnyRole(AppRole.desktop);
    return allowed ? const SideNavShell() : const LoginScreen();
  }
}
