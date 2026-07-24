import 'package:json_annotation/json_annotation.dart';

part 'role_application_response.g.dart';

/// A user's Curator/Organizer role application with its decision history (mirrors
/// the backend `RoleApplicationResponse`). The document bytes are never carried
/// here — [hasDocument] tells the client whether to offer the download endpoint.
@JsonSerializable()
class RoleApplicationResponse {
  RoleApplicationResponse({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.motivation,
    required this.hasDocument,
    required this.status,
    required this.createdAt,
    this.username,
    this.applicantName,
    this.roleName,
    this.regionId,
    this.regionName,
    this.documentContentType,
    this.decidedByUserId,
    this.decidedByUsername,
    this.decidedAt,
    this.rejectionReason,
    this.modifiedAt,
  });

  final int id;
  final int userId;
  final String? username;
  final String? applicantName;
  final int roleId;
  final String? roleName;
  final String motivation;
  final int? regionId;
  final String? regionName;
  final bool hasDocument;
  final String? documentContentType;

  /// Pending / Approved / Rejected (the enum name, never a raw int).
  final String status;

  final int? decidedByUserId;
  final String? decidedByUsername;
  final DateTime? decidedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';

  factory RoleApplicationResponse.fromJson(Map<String, dynamic> json) =>
      _$RoleApplicationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RoleApplicationResponseToJson(this);
}
