/// Reusable form-field validators — the client-side UX mirror of the backend
/// FluentValidation rules (the server stays the source of truth). Each returns
/// an error message or null, matching Flutter's `FormFieldValidator<String>`
/// shape, so a validator can be passed directly (`validator: Validators.email`)
/// or wrapped for extra arguments. Messages are English (the app's UI language).
class Validators {
  Validators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Fails when [value] is null or blank. [field] names the control in the
  /// message (e.g. "Username is required").
  static String? required(String? value, {String field = 'This field'}) =>
      (value == null || value.trim().isEmpty) ? '$field is required' : null;

  /// Requires a present, syntactically valid email address.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    return _emailPattern.hasMatch(value.trim())
        ? null
        : 'Enter a valid email address';
  }

  /// Fails when the trimmed length is below [min].
  static String? minLength(
    String? value,
    int min, {
    String field = 'This field',
  }) {
    if (value == null || value.trim().length < min) {
      return '$field must be at least $min characters';
    }
    return null;
  }

  /// Fails when the trimmed length exceeds [max]. A blank value passes — pair
  /// with [required] when the field is mandatory.
  static String? maxLength(
    String? value,
    int max, {
    String field = 'This field',
  }) {
    if (value != null && value.trim().length > max) {
      return '$field cannot exceed $max characters';
    }
    return null;
  }

  /// Standard password strength check (minimum length, default 8).
  static String? password(
    String? value, {
    int min = 8,
    String field = 'Password',
  }) =>
      minLength(value, min, field: field);

  /// Confirmation match (e.g. "confirm password"): [value] must equal [other].
  static String? match(
    String? value,
    String? other, {
    String message = 'Passwords do not match',
  }) =>
      value == other ? null : message;

  /// Runs [validators] in order, returning the first failure (or null). Handy
  /// for a field with several rules: `Validators.compose([...])`.
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
