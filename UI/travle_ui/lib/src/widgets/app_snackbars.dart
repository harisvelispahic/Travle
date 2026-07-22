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

  static void _show(
    BuildContext context,
    String message,
    Color background,
    Color foreground,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
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
