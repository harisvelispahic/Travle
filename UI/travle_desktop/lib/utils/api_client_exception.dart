import 'dart:convert';

/// Thrown when the API returns an error body we can show to the user
/// (e.g. [ClinetException] → HTTP 400 with `message` / `errors` from ExceptionFilter).
class ApiClientException implements Exception {
  ApiClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses JSON error payloads from Travle.WebAPI [ExceptionFilter].
class ApiErrorParser {
  ApiErrorParser._();

  /// Prefer root `message`, then `errors.clientError`, then other error lists.
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
          final v = errMap[key];
          parts.addAll(_messagesFromValue(v));
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
      return s.isEmpty ? [] : [s];
    }
    return [];
  }
}
