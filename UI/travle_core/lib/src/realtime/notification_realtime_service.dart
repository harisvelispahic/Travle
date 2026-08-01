import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../app_config.dart';
import '../auth/auth_provider.dart';
import '../models/notification_response.dart';

/// Thin wrapper over the SignalR connection to the backend notification hub
/// (`/hubs/notifications`). It authenticates with the current access token via
/// `accessTokenFactory` — which SignalR appends as the `access_token` query
/// parameter on the negotiate/WebSocket handshake, matching the API's bearer
/// wiring — and invokes [onNotification] whenever the server pushes the
/// `NotificationReceived` client method. Owned by [NotificationProvider]; the UI
/// never touches it directly.
///
/// It is best-effort: the durable source of truth is the DB row (loaded over
/// REST), so a failed connect or a dropped socket only costs the *live* nudge,
/// never a notification. Transient drops are handled by automatic reconnect;
/// [connect] is idempotent so it can double as a retry on screen open.
class NotificationRealtimeService {
  NotificationRealtimeService({required this.onNotification});

  /// The exact client method name the server invokes (see `SignalRNotificationPush`).
  static const String _method = 'NotificationReceived';

  final void Function(NotificationResponse notification) onNotification;

  HubConnection? _connection;
  bool _started = false;

  bool get isConnected => _started;

  Future<void> connect() async {
    if (_started) return;
    _started = true;

    final connection = HubConnectionBuilder()
        .withUrl(
          '${AppConfig.baseUrl}hubs/notifications',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => AuthProvider.accessToken ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    connection.on(_method, _handlePush);
    // If the connection closes for good (not a transient reconnect), allow a
    // later connect() to build a fresh one.
    connection.onclose(({Object? error}) => _started = false);

    _connection = connection;

    try {
      await connection.start();
    } catch (error) {
      // The API may be unreachable at login; leave it un-started so the next
      // connect() (e.g. on opening the notification centre) retries.
      debugPrint('Notification hub connect failed: $error');
      _started = false;
      _connection = null;
    }
  }

  void _handlePush(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    final payload = arguments.first;
    if (payload is Map) {
      onNotification(
        NotificationResponse.fromJson(Map<String, dynamic>.from(payload)),
      );
    }
  }

  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    _started = false;
    if (connection != null) {
      connection.off(_method);
      try {
        await connection.stop();
      } catch (_) {
        // Already closed / never fully started — nothing to clean up.
      }
    }
  }
}
