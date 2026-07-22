import 'dart:convert';

/// A user-presentable error carrying a message already translated from the
/// API's `ErrorResponse` contract (see the backend `ExceptionMiddleware`).
///
/// Providers throw this; screens present it (snackbar, inline field text, …).
/// It is the client-side counterpart of the server's exception pipeline: one
/// place understands the wire format, everything above it deals in messages.
class ApiClientException implements Exception {
  ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Translates the backend `ErrorResponse` JSON into a single human message.
///
/// The contract (from `ExceptionMiddleware`) is `{ message, errors }`, where
/// `errors` is a map of field/category → list of messages. We prefer the root
/// `message`, then FluentValidation's `clientError` bucket, then any remaining
/// error lists, joined by newlines.
class ApiErrorParser {
  ApiErrorParser._();

  static String? messageFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);

      final root = map['message'];
      if (root is String) {
        final m = root.trim();
        if (m.isNotEmpty) {
          return m;
        }
      }

      final errors = map['errors'];
      if (errors is Map) {
        final errMap = Map<String, dynamic>.from(errors);
        final parts = <String>[];

        void addKey(String key) {
          parts.addAll(_messagesFromValue(errMap[key]));
        }

        addKey('clientError');
        for (final key in errMap.keys) {
          if (key == 'clientError') {
            continue;
          }
          addKey(key);
        }

        final unique = parts.toSet().toList();
        if (unique.isNotEmpty) {
          return unique.join('\n');
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static List<String> _messagesFromValue(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? <String>[] : <String>[s];
    }
    return <String>[];
  }
}
