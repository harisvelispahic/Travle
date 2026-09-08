import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/travle_colors.dart';

/// Standardized snackbars carrying meaningful messages (never a bare "Success").
/// Colors come from the theme — success from the [TravleColors] extension,
/// errors from the [ColorScheme].
class AppSnackbars {
  AppSnackbars._();

  static void success(BuildContext context, String message, {Duration? duration}) {
    final colors = Theme.of(context).extension<TravleColors>()!;
    _show(context, message, colors.success, colors.onSuccess,
        Icons.check_circle_outline, duration: duration);
  }

  static void error(BuildContext context, String message, {Duration? duration}) {
    final scheme = Theme.of(context).colorScheme;
    _show(context, message, scheme.error, scheme.onError, Icons.error_outline,
        duration: duration);
  }

  /// A neutral, informational message (e.g. a transient hint like "Press back
  /// again to exit"). Uses the theme's inverse surface so it reads as a plain
  /// notice rather than a success or error. [duration] overrides the default so
  /// short-lived hints can match the interaction window they belong to.
  static void info(BuildContext context, String message, {Duration? duration}) {
    final scheme = Theme.of(context).colorScheme;
    _show(context, message, scheme.inverseSurface, scheme.onInverseSurface,
        Icons.info_outline, duration: duration);
  }

  static void _show(
    BuildContext context,
    String message,
    Color background,
    Color foreground,
    IconData icon, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          duration: duration ?? _readingTime(message),
          content: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: TravleTokens.space12),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      );
  }

  /// How long to leave a message up, from how much there is to read.
  ///
  /// A fixed four seconds is fine for "Saved" but not for the server's business
  /// rules, several of which are a couple of sentences that name counts and say
  /// what to do next — those used to vanish mid-sentence. Roughly 12 characters
  /// a second, floored at the old default so short messages are unchanged, and
  /// capped so nothing camps on the screen. A caller can still pass an explicit
  /// [Duration] when it knows better.
  static Duration _readingTime(String message) =>
      Duration(seconds: (message.length / 12).ceil().clamp(4, 12));
}
