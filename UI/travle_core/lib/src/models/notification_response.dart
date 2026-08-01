import 'package:json_annotation/json_annotation.dart';

part 'notification_response.g.dart';

/// An in-app notification for the current user (mirrors the backend
/// `NotificationResponse`). The same shape arrives from the REST list endpoints
/// and over SignalR, so both paths build this identically. [type] is the backend
/// `NotificationType` enum **name** (e.g. `"BookingConfirmed"`), which drives the
/// UI icon; [relatedEntityId] is an optional deep-link target interpreted per type.
@JsonSerializable()
class NotificationResponse {
  NotificationResponse({
    required this.id,
    required this.userId,
    required this.title,
    required this.text,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.relatedEntityId,
    this.readAt,
  });

  final int id;
  final int userId;
  final String title;
  final String text;
  final String type;
  final int? relatedEntityId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  /// Immutable-model helper for the optimistic mark-as-read update.
  NotificationResponse copyWith({bool? isRead, DateTime? readAt}) =>
      NotificationResponse(
        id: id,
        userId: userId,
        title: title,
        text: text,
        type: type,
        relatedEntityId: relatedEntityId,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
      );

  factory NotificationResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationResponseToJson(this);
}
