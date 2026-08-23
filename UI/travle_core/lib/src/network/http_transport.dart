import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_error.dart';

/// The single place that turns a *transport* failure into a presentable
/// [ApiClientException].
///
/// [validateResponse] on `BaseProvider` already translates every failing HTTP
/// **response**, but a request that never reaches the server produces no
/// response at all: `package:http` throws `SocketException` (API not running,
/// wrong host/port, no network, DNS failure), `http.ClientException` (the
/// connection dropped mid-flight), `HandshakeException` (TLS) or
/// [TimeoutException]. Those are not `ApiClientException`s, so every screen's
/// `on ApiClientException catch` would miss them and the raw framework error
/// would surface in the UI — or the screen would sit on its spinner forever.
///
/// Wrapping every call here means one message, in one voice, for the single
/// most likely failure a reviewer will hit: opening the app before the API is
/// up.
class HttpTransport {
  HttpTransport._();

  /// How long to wait before deciding the server is unreachable. Long enough
  /// for a cold-started container, short enough that the UI never hangs.
  static const Duration timeout = Duration(seconds: 20);

  static const String _unreachable =
      'Cannot reach the Travle server. Check that the API is running and that '
      'your connection is available, then try again.';

  /// Runs [send], converting any transport-level failure into an
  /// [ApiClientException]. Applies [timeout] so a hung connection cannot leave
  /// the UI spinning indefinitely.
  static Future<http.Response> guard(
    Future<http.Response> Function() send,
  ) async {
    try {
      return await send().timeout(timeout);
    } on ApiClientException {
      rethrow; // already presentable — never re-wrap
    } on TimeoutException {
      throw ApiClientException(
        'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw ApiClientException(_unreachable);
    } on HandshakeException {
      throw ApiClientException(_unreachable);
    } on http.ClientException {
      throw ApiClientException(_unreachable);
    }
  }
}
