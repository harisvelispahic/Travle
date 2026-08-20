import 'package:flutter/material.dart';

import 'travle_text_field.dart';

/// Prompts for the free-text reason that accompanies a decision the person on the
/// other end will read — rejecting a booking or an application, removing a review,
/// suspending an account, calling off a schedule. Resolves to the trimmed reason,
/// or **null** when the operator backs out (the Back button, Escape, or the
/// barrier), so a dismissal can never be mistaken for an empty reason.
///
/// Owning the [TextEditingController] inside this widget's [State] is the whole
/// point of centralising it. `showDialog`'s future completes *synchronously* when
/// the route is popped, while the dialog is still animating out with a live
/// `EditableText` — so the tempting `showDialog(...).whenComplete(controller.dispose)`
/// disposes the controller out from under the field mid-animation and throws
/// ("A TextEditingController was used after being disposed", surfacing in the app
/// as duplicate `_OverlayEntryWidgetState` GlobalKeys). It only bites when the
/// field still holds focus, which is exactly the Escape/barrier paths — tapping a
/// button moves focus off the field first. A `State`-owned controller is disposed
/// on unmount, after the field's own dispose, and is always safe.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? message,
  String cancelLabel = 'Back',
  bool isRequired = true,
  bool destructive = true,
  String requiredError = 'A reason is required',
  int maxLength = 500,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      message: message,
      cancelLabel: cancelLabel,
      isRequired: isRequired,
      destructive: destructive,
      requiredError: requiredError,
      maxLength: maxLength,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.message,
    required this.cancelLabel,
    required this.isRequired,
    required this.destructive,
    required this.requiredError,
    required this.maxLength,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String? message;
  final String cancelLabel;
  final bool isRequired;
  final bool destructive;
  final String requiredError;
  final int maxLength;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = widget.message;

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null) ...[
              Text(message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            TravleTextField(
              controller: _controller,
              label: widget.label,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: widget.maxLength,
              keyboardType: TextInputType.multiline,
              validator: !widget.isRequired
                  ? null
                  : (v) =>
                      (v == null || v.trim().isEmpty) ? widget.requiredError : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
