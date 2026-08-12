import 'package:flutter/material.dart';

/// A blocking "you need to sign in again" dialog, shown when the session ends
/// server-side (suspension, a role change, an expired/rejected token). It only
/// informs — the caller has already cleared the session and routed to login — so
/// its single action just dismisses it. Mirrors the tone of the mobile "you're now
/// a curator" re-login prompt, generalised to any reason. Not dismissible by
/// tapping outside, so the reason is acknowledged.
Future<void> showSessionEndedDialog(
  BuildContext context, {
  required String message,
  String title = 'Please sign in again',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_clock_outlined),
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sign in again'),
        ),
      ],
    ),
  );
}

/// Informational dialog for a role the user can use on **this device** being
/// granted or removed. The change has already applied (a silent token refresh —
/// no logout); this only tells them, so its single action just dismisses it. A
/// role change that does nothing on this device shows no dialog at all.
Future<void> showRoleChangeDialog(
  BuildContext context, {
  required String role,
  required bool gained,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(gained ? Icons.verified_user_outlined : Icons.info_outline),
      title: Text(gained ? "You're now a $role" : "You're no longer a $role"),
      content: Text(gained
          ? 'Your $role features are ready to use.'
          : 'Your $role features are no longer available.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
