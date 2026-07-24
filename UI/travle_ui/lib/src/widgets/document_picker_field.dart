import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Attach / remove row for an optional file upload. Shows an "attach" button
/// when empty, or the chosen file's name with a remove action. The actual
/// picking is performed by the caller (the file_picker plugin lives in the apps),
/// which passes down [fileName] and the two callbacks — so this widget is shared
/// design with no plugin dependency.
class DocumentPickerField extends StatelessWidget {
  const DocumentPickerField({
    super.key,
    required this.fileName,
    required this.onPick,
    required this.onRemove,
    this.pickLabel = 'Attach document (optional)',
  });

  /// The chosen file's name, or null when nothing is attached yet.
  final String? fileName;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;
  final String pickLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (fileName == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.attach_file),
          label: Text(pickLabel),
        ),
      );
    }
    return Row(
      children: [
        Icon(Icons.description_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: TravleTokens.space8),
        Expanded(
          child: Text(
            fileName!,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close),
          tooltip: 'Remove document',
        ),
      ],
    );
  }
}
