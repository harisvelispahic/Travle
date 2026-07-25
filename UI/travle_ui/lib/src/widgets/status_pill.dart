import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/travle_colors.dart';

/// The semantic tone of a [StatusPill]. Screens map their domain status to a tone
/// (e.g. a Pending destination → [warning], Approved → [success]).
enum StatusTone { success, warning, info, danger, neutral }

/// A small rounded status pill with a semantic colour, for lists and detail
/// headers (destination moderation status, booking status, …). Colours come from
/// the theme (the [TravleColors] extension + the error colour), never hardcoded.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TravleColors>()!;
    final scheme = theme.colorScheme;

    final (Color background, Color foreground) = switch (tone) {
      StatusTone.success => (colors.success, colors.onSuccess),
      StatusTone.warning => (colors.warning, colors.onWarning),
      StatusTone.info => (colors.info, colors.onInfo),
      StatusTone.danger => (scheme.error, scheme.onError),
      StatusTone.neutral => (colors.neutral, colors.onNeutral),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TravleTokens.space12,
        vertical: TravleTokens.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(TravleTokens.radiusPill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
