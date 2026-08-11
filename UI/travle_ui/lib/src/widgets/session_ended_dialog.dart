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
