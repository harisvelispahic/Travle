import 'dart:typed_data';

import '../models/role_application_response.dart';
import '../models/role_application_submit_request.dart';
import '../models/role_option_response.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Curator/Organizer role applications (`/RoleApplications`). Submit + read-mine
/// are for any authenticated user; the moderation queue (plain paginated `get`)
/// and approve/reject are admin-only (enforced server-side).
class RoleApplicationProvider extends BaseProvider<RoleApplicationResponse> {
  RoleApplicationProvider() : super('RoleApplications');

  @override
  RoleApplicationResponse fromJson(Map<String, dynamic> json) =>
      RoleApplicationResponse.fromJson(json);

  /// Elevated roles the current user may still apply for (resolve the target role
  /// id by name from this set — no hardcoded ids).
  Future<List<RoleOptionResponse>> applicableRoles() async {
    final json = await getAction('applicable-roles');
    return ((json as List?) ?? [])
        .map((e) => RoleOptionResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Submits an application (`POST /RoleApplications`). Returns the created row.
  Future<RoleApplicationResponse> submit(RoleApplicationSubmitRequest request) =>
      insert(request.toJson());

  /// The current user's own applications (`GET /RoleApplications/mine`).
  Future<SearchResult<RoleApplicationResponse>> mine({dynamic filter}) async {
    final json = await getAction('mine', filter: filter) as Map<String, dynamic>;
    return SearchResult<RoleApplicationResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
  }

  /// Admin: approve a pending application (grants the role live server-side).
  Future<RoleApplicationResponse> approve(int id) async {
    final json = await postAction('$id/Approve');
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: reject a pending application with a mandatory reason.
  Future<RoleApplicationResponse> reject(int id, String reason) async {
    final json = await postAction('$id/Reject', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  /// Downloads the supporting document bytes (owner-or-admin).
  Future<Uint8List> documentBytes(int id) => getBytes('$id/document');
}
