import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../auth/auth_provider.dart';
import 'api_error.dart';
import 'search_result.dart';

/// Generic API data-access base — the client analogue of the backend
/// `BaseCRUDService`. Subclass as `XProvider extends BaseProvider<X>` and
/// override [fromJson]; the CRUD verbs, auth header, query-string building, a
/// 401→refresh→retry pass, and error translation come for free.
abstract class BaseProvider<T> with ChangeNotifier {
  BaseProvider(this.endpoint);

  /// Resource segment appended to [AppConfig.baseUrl], e.g. `Destinations`.
  final String endpoint;

  String get _base => AppConfig.baseUrl;

  Future<SearchResult<T>> get({dynamic filter}) async {
    var url = '$_base$endpoint';
    if (filter != null) {
      url = '$url?${getQueryString(_asMap(filter))}';
    }
    final uri = Uri.parse(url);
    final response = await _send(() => http.get(uri, headers: _headers()));
    validateResponse(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return SearchResult<T>()
      ..totalCount = data['totalCount'] as int?
      ..items = (data['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
  }

  Future<T> getById(int id) async {
    final uri = Uri.parse('$_base$endpoint/$id');
    final response = await _send(() => http.get(uri, headers: _headers()));
    validateResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<T> insert(dynamic request) async {
    final uri = Uri.parse('$_base$endpoint');
    final body = jsonEncode(request);
    final response =
        await _send(() => http.post(uri, headers: _headers(), body: body));
    validateResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<T> update(int id, [dynamic request]) async {
    final uri = Uri.parse('$_base$endpoint/$id');
    final body = jsonEncode(request);
    final response =
        await _send(() => http.put(uri, headers: _headers(), body: body));
    validateResponse(response);
    return fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> remove(int id) async {
    final uri = Uri.parse('$_base$endpoint/$id');
    final response = await _send(() => http.delete(uri, headers: _headers()));
    validateResponse(response);
  }

  /// POSTs [body] to `endpoint[/subPath]` and returns the decoded JSON (or null
  /// for an empty response). Reuses the auth header + 401→refresh pass. For
  /// action endpoints that aren't plain CRUD (e.g. `Users/onboarding-interests`).
  Future<dynamic> postAction(String? subPath, [dynamic body]) async {
    final url =
        subPath == null ? '$_base$endpoint' : '$_base$endpoint/$subPath';
    final response = await _send(
      () => http.post(
        Uri.parse(url),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    validateResponse(response);
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  /// Override in subclasses to build [T] from a decoded JSON object.
  T fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromJson not implemented for $runtimeType');
  }

  /// Runs [request]; on a 401, silently refreshes the token once and retries.
  /// A failed refresh clears the session and the retry's 401 falls through to
  /// [validateResponse], which surfaces the session-expired message.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode == 401 && AuthProvider.instance != null) {
      final refreshed = await AuthProvider.instance!.tryRefresh();
      if (refreshed) {
        response = await request();
      }
    }
    return response;
  }

  Map<String, dynamic> _asMap(dynamic filter) {
    if (filter is Map<String, dynamic>) return filter;
    if (filter is Map) return Map<String, dynamic>.from(filter);
    return (filter as dynamic).toJson() as Map<String, dynamic>;
  }

  Map<String, String> _headers() {
    final token = AuthProvider.accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Translates a non-success response into an [ApiClientException] carrying an
  /// API-derived message (via [ApiErrorParser]).
  void validateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    if (response.statusCode == 401) {
      throw ApiClientException(
        'Your session has expired. Please sign in again.',
      );
    }
    final parsed = ApiErrorParser.messageFromBody(response.body);
    if (response.statusCode >= 500) {
      throw ApiClientException(
        parsed ?? 'Server error. Please try again later.',
      );
    }
    throw ApiClientException(
      parsed ?? 'Request could not be completed. Please try again.',
    );
  }

  /// Serializes a (possibly nested) params map into a Travle-API query string,
  /// matching the backend's list/array binding (`Ids[0]=…`, `Filter.X=…`).
  String getQueryString(
    Map params, {
    String prefix = '&',
    bool inRecursion = false,
  }) {
    String query = '';
    params.forEach((key, value) {
      if (inRecursion) {
        if (key is int) {
          key = '[$key]';
        } else {
          key = '.$key';
        }
      }
      if (value is String || value is int || value is double || value is bool) {
        final encoded = value is String ? Uri.encodeComponent(value) : value;
        query += '$prefix$key=$encoded';
      } else if (value is DateTime) {
        query += '$prefix$key=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        final map = value is List ? value.asMap() : value;
        map.forEach((k, v) {
          query += getQueryString(
            {k: v},
            prefix: '$prefix$key',
            inRecursion: true,
          );
        });
      }
    });
    return query;
  }
}
