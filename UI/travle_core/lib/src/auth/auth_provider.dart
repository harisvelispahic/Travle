import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../app_config.dart';
import '../network/api_error.dart';

/// Owns the authenticated session: tokens, the decoded JWT, and the user's
/// roles. The access token is kept in a static field so [BaseProvider] can read
/// it without a widget context, and a static [instance] pointer lets the
/// provider request a silent refresh on a 401.
///
/// The **refresh token is persisted** in OS-encrypted storage (Android
/// Keystore / Windows Credential Locker), so relaunching the app restores the
/// session by silently exchanging it for a fresh access token. Backend refresh
/// tokens rotate, so the newest one is re-persisted on every refresh. Errors are
/// surfaced as [ApiClientException] for the screens to present.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    instance = this;
    unawaited(_restore());
  }

  /// The single registered instance, used by [BaseProvider] (which has no
  /// context) to trigger [tryRefresh] on a 401.
  static AuthProvider? instance;

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _refreshKey = 'travle_refresh_token';

  // JWT payload keys. The backend writes the short forms via
  // JwtSecurityTokenHandler's outbound map; the long URIs are kept as
  // defensive fallbacks in case the token handler is ever swapped.
  static const String _roleClaimShort = 'role';
  static const String _roleClaimUri =
      'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';
  static const String _nameClaimShort = 'unique_name';
  static const String _idClaimShort = 'nameid';

  static String? _accessToken;
  static String? get accessToken => _accessToken;

  String? _refreshToken;
  Map<String, dynamic>? _decodedToken;
  List<String> _roles = <String>[];

  bool _initializing = true;

  /// True while the app is restoring a persisted session on launch — show a
  /// splash until this clears, then either the shell or the login screen.
  bool get isInitializing => _initializing;

  Map<String, dynamic>? get decodedToken => _decodedToken;
  List<String> get roles => List.unmodifiable(_roles);
  bool get isAuthenticated => _accessToken != null;

  String? get username =>
      _decodedToken?[_nameClaimShort] as String? ??
      _decodedToken?['name'] as String?;

  int? get userId {
    final raw = _decodedToken?[_idClaimShort] ?? _decodedToken?['sub'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// True when the session holds at least one of [allowed] — the OR-match used
  /// for per-app login gating (a multi-role account passes if any role fits).
  bool hasAnyRole(Set<String> allowed) => _roles.any(allowed.contains);

  /// Restores a persisted session on launch: reads the stored refresh token and
  /// silently exchanges it for a fresh access token. A missing/expired/revoked
  /// token simply leaves the user signed out.
  Future<void> _restore() async {
    try {
      final stored = await _storage.read(key: _refreshKey);
      if (stored != null && stored.isNotEmpty) {
        _refreshToken = stored;
        await tryRefresh();
      }
    } catch (_) {
      // Any restore failure just falls back to the login screen.
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}Access/Login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (_isSuccess(response)) {
      _applySession(jsonDecode(response.body) as Map<String, dynamic>);
      return;
    }
    if (response.statusCode == 401) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'Invalid username or password.',
      );
    }
    throw ApiClientException(
      ApiErrorParser.messageFromBody(response.body) ??
          'Sign in failed. Please try again.',
    );
  }

  /// Exchanges the refresh token for a fresh access token. On failure the
  /// session is cleared (listeners notified → the app returns to login).
  /// Returns whether a new access token was obtained.
  Future<bool> tryRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}Access/RefreshToken'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (_isSuccess(response)) {
        _applySession(jsonDecode(response.body) as Map<String, dynamic>);
        return true;
      }
    } catch (_) {
      // Network/parse failure — treated the same as a rejected refresh below.
    }
    _clearSession();
    return false;
  }

  /// Best-effort server-side revocation (deletes all refresh tokens), then
  /// clears the local session and the persisted token regardless of outcome.
  Future<void> logout() async {
    final token = _accessToken;
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}Access/Logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (_) {
        // Ignore — the local session is dropped either way.
      }
    }
    _clearSession();
  }

  bool _isSuccess(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  void _applySession(Map<String, dynamic> data) {
    _accessToken = data['accessToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    _decodedToken =
        _accessToken != null ? JwtDecoder.decode(_accessToken!) : null;
    _roles = _decodedToken != null ? _extractRoles(_decodedToken!) : <String>[];
    if (_refreshToken != null) {
      unawaited(_storage.write(key: _refreshKey, value: _refreshToken));
    }
    notifyListeners();
  }

  void _clearSession() {
    _accessToken = null;
    _refreshToken = null;
    _decodedToken = null;
    _roles = <String>[];
    unawaited(_storage.delete(key: _refreshKey));
    notifyListeners();
  }

  /// Reads roles from the token, tolerating single-role (String) vs multi-role
  /// (List) payloads and short-vs-URI claim keys.
  List<String> _extractRoles(Map<String, dynamic> jwt) {
    final result = <String>{};
    for (final claim in [jwt[_roleClaimShort], jwt[_roleClaimUri], jwt['roles']]) {
      if (claim is String && claim.isNotEmpty) {
        result.add(claim);
      } else if (claim is List) {
        result.addAll(
          claim.map((e) => e.toString()).where((s) => s.isNotEmpty),
        );
      }
    }
    return result.toList();
  }
}
