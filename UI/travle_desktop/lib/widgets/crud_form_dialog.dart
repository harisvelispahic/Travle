import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travle_ui/travle_ui.dart';

/// The kind of control rendered for a [CrudField].
enum CrudFieldKind { text, integer, dropdown }

/// One selectable option in a [CrudFieldKind.dropdown] field: a [value] (the id
/// sent to the API — never shown) paired with a human [label].
class CrudOption {
  const CrudOption(this.value, this.label);
  final Object value;
  final String label;
}

/// Declares one editable field in a [CrudFormDialog].
class CrudField {
  const CrudField({
    required this.id,
    required this.label,
    required this.kind,
    this.required = true,
    this.hint,
    this.helperText,
    this.min,
    this.max,
    this.maxLength,
    this.optionsLoader,
    this.dependsOn,
  });

  /// Key under which this field's value is returned in the result map.
  final String id;
  final String label;
  final CrudFieldKind kind;

  /// When false the field may be left empty (e.g. an open-ended upper bound).
  final bool required;
  final String? hint;
  final String? helperText;

  /// Inclusive bounds for [CrudFieldKind.integer].
  final int? min;
  final int? max;
  final int? maxLength;

  /// For [CrudFieldKind.dropdown]: loads the options, given the form's current
  /// values (so a dependent dropdown can filter by a parent selection).
  final Future<List<CrudOption>> Function(Map<String, Object?> current)?
      optionsLoader;

  /// Id of another field this dropdown depends on; changing it reloads these
  /// options and clears this selection (drives Country→Region chaining).
  final String? dependsOn;
}

/// Opens the standard reference CRUD form: an X-close top-right, a title, aligned
/// label/field rows in a validate-on-blur [Form], and Cancel/Save.
///
/// On Save the (validated) values are handed to [onSubmit], which performs the
/// API call and returns null on success (the dialog closes and this resolves to
/// `true`) or a human error message that is shown inline while the dialog stays
/// open with the user's input intact — so a server-side conflict (e.g. a
/// duplicate name) doesn't discard the form. Resolves to null when cancelled.
Future<bool?> showCrudFormDialog(
  BuildContext context, {
  required String title,
  required List<CrudField> fields,
  required String saveLabel,
  required Future<String?> Function(Map<String, Object?> values) onSubmit,
  Map<String, Object?> initialValues = const {},
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CrudFormDialog(
      title: title,
      fields: fields,
      saveLabel: saveLabel,
      onSubmit: onSubmit,
      initialValues: initialValues,
    ),
  );
}

class CrudFormDialog extends StatefulWidget {
  const CrudFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.saveLabel,
    required this.onSubmit,
    required this.initialValues,
  });

  final String title;
  final List<CrudField> fields;
  final String saveLabel;
  final Future<String?> Function(Map<String, Object?> values) onSubmit;
  final Map<String, Object?> initialValues;

  @override
  State<CrudFormDialog> createState() => _CrudFormDialogState();
}

class _CrudFormDialogState extends State<CrudFormDialog> {
  final _formKey = GlobalKey<FormState>();

  /// Text/integer controllers, keyed by field id.
  final Map<String, TextEditingController> _controllers = {};

  /// Current dropdown selections, keyed by field id.
  final Map<String, Object?> _dropdownValues = {};

  /// Loaded dropdown options + their loading state, keyed by field id.
  final Map<String, List<CrudOption>?> _options = {};
  final Map<String, bool> _optionsLoading = {};

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initialValues[field.id];
      switch (field.kind) {
        case CrudFieldKind.text:
        case CrudFieldKind.integer:
          _controllers[field.id] =
              TextEditingController(text: initial?.toString() ?? '');
        case CrudFieldKind.dropdown:
          _dropdownValues[field.id] = initial;
          // Set the flag directly (we're pre-first-build; setState would throw),
          // then kick off the async load which setStates its result.
          _optionsLoading[field.id] = true;
          _loadOptions(field);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Loads a dropdown's options. Callers must have already set
  /// `_optionsLoading[field.id] = true` (directly in initState, or inside the
  /// setState that clears a dependent selection) so this only setStates results.
  Future<void> _loadOptions(CrudField field) async {
    final loader = field.optionsLoader;
    if (loader == null) return;
    try {
      final options = await loader(_currentValues());
      if (!mounted) return;
      setState(() {
        _options[field.id] = options;
        _optionsLoading[field.id] = false;
        // Drop a stale selection that isn't among the freshly loaded options.
        final selected = _dropdownValues[field.id];
        if (selected != null && !options.any((o) => o.value == selected)) {
          _dropdownValues[field.id] = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _options[field.id] = <CrudOption>[];
        _optionsLoading[field.id] = false;
      });
    }
  }

  /// A snapshot of every field's current value (used by dependent option loaders).
  Map<String, Object?> _currentValues() {
    final values = <String, Object?>{};
    for (final field in widget.fields) {
      switch (field.kind) {
        case CrudFieldKind.text:
          values[field.id] = _controllers[field.id]!.text.trim();
        case CrudFieldKind.integer:
          values[field.id] = _parseInt(_controllers[field.id]!.text);
        case CrudFieldKind.dropdown:
          values[field.id] = _dropdownValues[field.id];
      }
    }
    return values;
  }

  static int? _parseInt(String raw) {
    final t = raw.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  void _onDropdownChanged(CrudField field, Object? value) {
    final dependents =
        widget.fields.where((f) => f.dependsOn == field.id).toList();
    setState(() {
      _dropdownValues[field.id] = value;
      // Clear each chained field's stale selection and flag it loading; the
      // control renders a spinner (a non-FormField) meanwhile, so when its
      // dropdown returns it is rebuilt fresh from the cleared value.
      for (final dependent in dependents) {
        _dropdownValues[dependent.id] = null;
        _optionsLoading[dependent.id] = true;
      }
    });
    for (final dependent in dependents) {
      _loadOptions(dependent);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final error = await widget.onSubmit(_currentValues());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _submitError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(TravleTokens.space24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUnfocus,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: theme.textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed:
                          _submitting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: TravleTokens.space16),
                for (final field in widget.fields) ...[
                  _buildField(field),
                  const SizedBox(height: TravleTokens.space16),
                ],
                if (_submitError != null) ...[
                  _ErrorBanner(message: _submitError!),
                  const SizedBox(height: TravleTokens.space16),
                ],
                const SizedBox(height: TravleTokens.space8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _submitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: TravleTokens.space12),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.saveLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(CrudField field) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.only(top: TravleTokens.space12),
            child: Text(field.required ? '${field.label} *' : field.label),
          ),
        ),
        Expanded(child: _buildControl(field)),
      ],
    );
  }

  Widget _buildControl(CrudField field) {
    switch (field.kind) {
      case CrudFieldKind.text:
        return TravleTextField(
          controller: _controllers[field.id],
          hint: field.hint,
          helperText: field.helperText,
          maxLength: field.maxLength,
          validator: (value) {
            if (field.required && (value == null || value.trim().isEmpty)) {
              return '${field.label} is required';
            }
            return null;
          },
        );
      case CrudFieldKind.integer:
        return TravleTextField(
          controller: _controllers[field.id],
          hint: field.hint,
          helperText: field.helperText,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) => _validateInteger(field, value),
        );
      case CrudFieldKind.dropdown:
        return _buildDropdown(field);
    }
  }

  String? _validateInteger(CrudField field, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return field.required ? '${field.label} is required' : null;
    }
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Enter a whole number';
    if (field.min != null && parsed < field.min!) {
      return '${field.label} must be at least ${field.min}';
    }
    if (field.max != null && parsed > field.max!) {
      return '${field.label} must be at most ${field.max}';
    }
    return null;
  }

  Widget _buildDropdown(CrudField field) {
    final loading = _optionsLoading[field.id] ?? false;
    final options = _options[field.id];

    if (loading || options == null) {
      return const InputDecorator(
        decoration: InputDecoration(),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: TravleTokens.space4),
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return DropdownButtonFormField<Object>(
      initialValue: _dropdownValues[field.id],
      isExpanded: true,
      decoration: InputDecoration(
        hintText: field.hint ?? 'Select…',
        helperText: field.helperText,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem<Object>(
            value: option.value,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (value) {
        if (field.required && value == null) {
          return '${field.label} is required';
        }
        return null;
      },
      onChanged: (value) => _onDropdownChanged(field, value),
    );
  }
}

/// Inline banner for a server-side submit error (e.g. a delete/insert conflict),
/// shown inside the form so the user's input is preserved.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TravleTokens.space12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(TravleTokens.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: TravleTokens.space8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

