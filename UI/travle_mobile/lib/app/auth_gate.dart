import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:travle_core/travle_core.dart';
import 'package:travle_ui/travle_ui.dart';

import '../layouts/bottom_nav_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/onboarding_screen.dart';

/// Root switch: shows the app shell only for an authenticated account that holds
/// a mobile role (Traveler/Curator); otherwise the login screen. An organizer/
/// admin who signs in here is treated as not-allowed — [LoginScreen] clears that
/// session and explains why, so the shell never appears for the wrong role.
///
/// It also owns the app-wide **session-ended** handling. A server-side auth change
/// (suspension, a role grant/revoke) rolls the account's security stamp, so the
/// current token is rejected on its next use. On the matching live push — or on an
/// involuntary token loss surfaced by [BaseProvider] — it first tries a silent
/// refresh (seamless when the refresh token was kept, e.g. gaining a role you
/// applied for is not, but an admin changing their own non-admin role is); if that
/// fails, it routes to login and explains why. Being the stable root (it never
/// unmounts), it's the right place for both.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<NotificationResponse>? _pushSub;
  bool _sessionEndedShowing = false;
  bool _handlingPush = false;

  /// Bumped to ask the shell to return to the Home tab — used after a role loss
  /// so no now-forbidden context (and the stale profile menu it belonged to) is
  /// left showing.
  final ValueNotifier<int> _homeReset = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // Reactive path: a failed 401 refresh in BaseProvider hands off here.
    AuthProvider.onSessionEnded = _handleSessionEnded;
    // Proactive path: a live notification about our own account.
    _pushSub = context.read<NotificationProvider>().pushes.listen(_onPush);
  }

  @override
  void dispose() {
    if (AuthProvider.onSessionEnded == _handleSessionEnded) {
      AuthProvider.onSessionEnded = null;
    }
    _pushSub?.cancel();
    _homeReset.dispose();
    super.dispose();
  }

  Future<void> _onPush(NotificationResponse notification) async {
    if (_handlingPush ||
        !sessionAffectingNotificationTypes.contains(notification.type)) {
      return;
    }
    _handlingPush = true;
    try {
      final auth = context.read<AuthProvider>();
      final before = auth.roles.toSet();
      // Our access token's stamp was just rolled. A silent refresh succeeds unless the
      // account was suspended / its refresh dropped, in which case we end the session.
      final refreshed = await auth.tryRefresh();
      if (!mounted) return;
      if (!refreshed) {
        await _handleSessionEnded(
            sessionEndedReason(notification.type, notification.text));
        return;
      }
      // Seamless: the token's claims changed. Re-fetch the cached profile so its roles
      // (which gate the profile menu — e.g. the "My destinations" item) match the new
      // token; otherwise a revoked role's entry would linger on the profile tab.
      await auth.refreshCurrentUser();
      if (!mounted) return;
      // Inform the user only about a role change that actually means something on this
      // (mobile) device — a desktop-only grant stays silent.
      final after = auth.roles.toSet();
      final gained =
          after.difference(before).where(AppRole.mobile.contains).toList();
      final lost =
          before.difference(after).where(AppRole.mobile.contains).toList();
      if (gained.isNotEmpty) {
        await showRoleChangeDialog(context, role: gained.first, gained: true);
      } else if (lost.isNotEmpty) {
        // Pop any screen the lost role gated, then return to the Home tab so the user
        // isn't left in a now-forbidden context (and the stale profile menu is off-screen).
        Navigator.of(context).popUntil((route) => route.isFirst);
        _homeReset.value++;
        if (!mounted) return;
        await showRoleChangeDialog(context, role: lost.first, gained: false);
      }
    } finally {
      _handlingPush = false;
    }
  }

  Future<void> _handleSessionEnded(String message) async {
    if (_sessionEndedShowing || !mounted) return;
    _sessionEndedShowing = true;
    // Drop any pushed routes so the login screen (this gate's unauthenticated state) shows.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await showSessionEndedDialog(context, message: message);
    _sessionEndedShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) return const AppSplash();
    if (!auth.isAuthenticated || !auth.hasAnyRole(AppRole.mobile)) {
      return const LoginScreen();
    }
    // Wait for the post-login profile fetch, then route a not-yet-onboarded
    // traveler to onboarding before the shell.
    if (!auth.sessionResolved) return const AppSplash();
    if (auth.onboardingActive) return const OnboardingScreen();
    return BottomNavShell(homeReset: _homeReset);
  }
}
