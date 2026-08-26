/// App-wide configuration injected at build/run time.
///
/// The single source of truth for the API base URL. The course requires the
/// address to be configurable from the command line and read through
/// `String.fromEnvironment('API_BASE_URL')`:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5121
/// ```
///
/// A file works too and is what the checked-in launch configurations use:
/// `--dart-define-from-file=env.json`.
///
/// The value may be given with or without a trailing slash — [baseUrl]
/// normalizes it, because providers concatenate `baseUrl + endpoint`
/// (e.g. `Access/Login`).
///
/// Defaults target `localhost:5121`, the port docker-compose publishes for the
/// API (`API_HOST_PORT`), which is also correct for the Windows desktop app and
/// for a physical phone bridged with `adb reverse tcp:5121 tcp:5121`. The
/// Android emulator instead needs `10.0.2.2`; select it with
/// `--dart-define-from-file=env.json` (the mobile app's default file).
class AppConfig {
  AppConfig._();

  /// Course-mandated name (§3.3).
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const String _fallback = 'http://localhost:5121/';

  /// The API root, always ending in a single `/`.
  static String get baseUrl {
    final raw = _apiBaseUrl.isNotEmpty ? _apiBaseUrl : _fallback;
    final trimmed = raw.trim();
    return trimmed.endsWith('/') ? trimmed : '$trimmed/';
  }
}
