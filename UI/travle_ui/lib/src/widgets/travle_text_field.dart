import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's standard form text field. It gives every form a consistent look and
/// two behaviours the raw [TextFormField] doesn't out of the box here:
///
/// * **Password reveal** — set [obscure] and a show/hide eye toggle is rendered.
/// * **Validate on blur** — inherited from the enclosing
///   `Form(autovalidateMode: AutovalidateMode.onUnfocus)`, so the error appears
///   when the user leaves a field (and then updates live), not only on submit.
///   Wrap forms that use this field in that mode.
class TravleTextField extends StatefulWidget {
  const TravleTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscure = false,
    this.prefixIcon,
    this.enabled = true,
    this.autofillHints,
    this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  /// When true the text is masked and a show/hide toggle is shown in the suffix.
  final bool obscure;
  final IconData? prefixIcon;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  State<TravleTextField> createState() => _TravleTextFieldState();
}

class _TravleTextFieldState extends State<TravleTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      obscureText: _obscured,
      enabled: widget.enabled,
      autofillHints: widget.autofillHints,
      maxLength: widget.maxLength,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        prefixIcon:
            widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(_obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscured = !_obscured),
                tooltip: _obscured ? 'Show password' : 'Hide password',
              )
            : null,
      ),
    );
  }
}
