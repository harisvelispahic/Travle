import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../app_config.dart';
import '../models/forgot_password_request.dart';
import '../models/reset_password_request.dart';
import '../models/user_register_request.dart';
import '../models/user_response.dart';
import '../network/api_error.dart';
import 'app_role.dart';

/// Owns the authenticated session: tokens, the decoded JWT, the user's roles,
/// and the current user profile (from `GET /Access/Me`). The access token is
/// kept in a static field so [BaseProvider] can read it without a widget
/// context, and a static [instance] pointer lets the provider request a silent
/// refresh on a 401.
///
/// The refresh token is persisted in OS-encrypted storage, so relaunching the
/// app restores the session. After every login/restore the profile is fetched
/// so the app can route a not-yet-onboarded traveler to onboarding.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    instance = this;
    unawaited(_restore());
  }

  static AuthProvider? instance;

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _refreshKey = 'travle_refresh_token';

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
  bool _sessionResolved = false;
  UserResponse? _currentUser;
  bool _onboardingActive = false;

  /// True while restoring a persisted session on launch — show a splash.
  bool get isInitializing => _initializing;

  /// True once the post-auth profile fetch (`/Me`) has finished. The gate shows
  /// a splash while this is false for an authenticated user.
  bool get sessionResolved => _sessionResolved;

  /// The signed-in user's profile, or null before it's fetched / when logged out.
  UserResponse? get currentUser => _currentUser;

  /// Latched decision (per launch) that the onboarding step should be shown.
  /// Set from the profile after login/restore; cleared by [finishOnboarding] /
  /// [snoozeOnboarding]. Kept separate from [UserResponse.isOnboarded] so that
  /// incrementing the prompt count mid-view can't yank the screen away.
  bool get onboardingActive => _onboardingActive;

  Map<String, dynamic>? get decodedToken => _decodedToken;
  List<String> get roles => List.unmodifiable(_roles);
  bool get isAuthenticated => _accessToken != null;

  bool get _isTraveler => _roles.contains(AppRole.traveler);

  String? get username =>
      _decodedToken?[_nameClaimShort] as String? ??
      _decodedToken?['name'] as String?;

  int? get userId {
    final raw = _decodedToken?[_idClaimShort] ?? _decodedToken?['sub'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  bool hasAnyRole(Set<String> allowed) => _roles.any(allowed.contains);

  /// Restores a persisted session on launch and resolves the profile.
  Future<void> _restore() async {
    try {
      final stored = await _storage.read(key: _refreshKey);
      if (stored != null && stored.isNotEmpty) {
        _refreshToken = stored;
        if (await tryRefresh()) {
          await _resolveSession();
        }
      }
    } catch (_) {
      // Any restore failure just falls back to the login screen.
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  /// Fetches the current profile and latches whether onboarding is due. Called
  /// after an interactive login and after a launch restore — never from the
  /// 401 refresh path, so a mid-session token refresh can't re-trigger it.
  Future<void> _resolveSession() async {
    _sessionResolved = false;
    final me = await _fetchMe();
    _currentUser = me;
    _onboardingActive = me != null && _isTraveler && !me.isOnboarded;
    _sessionResolved = true;
    notifyListeners();
  }

  Future<UserResponse?> _fetchMe() async {
    final token = _accessToken;
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}Access/Me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (_isSuccess(response)) {
        return UserResponse.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Non-fatal — the app proceeds without profile-driven routing.
    }
    return null;
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}Access/Login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (_isSuccess(response)) {
      _applySession(jsonDecode(response.body) as Map<String, dynamic>);
      await _resolveSession();
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

  /// Registers a new account (server assigns the Traveler role) and signs in
  /// immediately, so onboarding routing kicks in right after.
  Future<void> register(UserRegisterRequest request) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}Access/Register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (!_isSuccess(response)) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'Registration failed. Please try again.',
      );
    }
    await login(request.username, request.password);
  }

  Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}Access/ForgotPassword'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(ForgotPasswordRequest(email: email).toJson()),
    );
    if (!_isSuccess(response)) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'Could not start the password reset. Please try again.',
      );
    }
  }

  Future<void> resetPassword(ResetPasswordRequest request) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}Access/ResetPassword'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (!_isSuccess(response)) {
      throw ApiClientException(
        ApiErrorParser.messageFromBody(response.body) ??
            'Could not reset your password. Please check the code and try again.',
      );
    }
  }

  /// Exchanges the refresh token for a fresh access token. On failure the
  /// session is cleared. Returns whether a new access token was obtained. Does
  /// not re-resolve the profile — that's [login]/[_restore]'s job.
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
      // Treated the same as a rejected refresh below.
    }
    _clearSession();
    return false;
  }

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

  /// Called when the user completes onboarding (picked interests). Updates the
  /// profile and clears the latch so the gate advances to the shell.
  void finishOnboarding(UserResponse user) {
    _currentUser = user;
    _onboardingActive = false;
    notifyListeners();
  }

  /// Called when the user skips onboarding this launch (client-side dismiss).
  void snoozeOnboarding() {
    _onboardingActive = false;
    notifyListeners();
  }

  /// Refreshes the held profile (e.g. after the display-prompt increment)
  /// without touching the onboarding latch.
  void updateCurrentUser(UserResponse user) {
    _currentUser = user;
    notifyListeners();
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
    _currentUser = null;
    _onboardingActive = false;
    _sessionResolved = false;
    unawaited(_storage.delete(key: _refreshKey));
    notifyListeners();
  }

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
