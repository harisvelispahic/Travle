import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/travle_colors.dart';

/// Standardized snackbars carrying meaningful messages (never a bare "Success").
/// Colors come from the theme — success from the [TravleColors] extension,
/// errors from the [ColorScheme].
class AppSnackbars {
  AppSnackbars._();

  static void success(BuildContext context, String message) {
    final colors = Theme.of(context).extension<TravleColors>()!;
    _show(context, message, colors.success, colors.onSuccess,
        Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(context, message, scheme.error, scheme.onError, Icons.error_outline);
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
          duration: duration ?? const Duration(seconds: 4),
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
}
