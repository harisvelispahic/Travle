/// App-wide configuration injected at build/run time.
///
/// The single source of truth for the API base URL. Provide it with
/// `--dart-define=BASE_URL=http://host:5126/` or, preferably, a file:
/// `--dart-define-from-file=env.json`. The trailing slash is required because
/// providers concatenate `baseUrl + endpoint` (e.g. `Access/Login`).
///
/// The default targets `localhost` — correct for the desktop app and for a
/// physical phone bridged with `adb reverse tcp:5126 tcp:5126`. The Android
/// emulator instead needs `10.0.2.2`; select it by passing `env.emulator.json`.
/// Under Docker the API host port is `5121`, not `5126`.
class AppConfig {
  AppConfig._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5126/',
  );
}
