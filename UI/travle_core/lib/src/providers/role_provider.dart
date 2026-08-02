import '../models/role_option_response.dart';
import '../network/base_provider.dart';

/// Read-only lookup of the application roles (`GET /Roles`, admin-only), backing
/// the user-management create form and the grant/revoke picker. The endpoint
/// returns a plain list (not the paginated `{items,totalCount}` shape), so it
/// uses [getAction] rather than the base `get`.
class RoleProvider extends BaseProvider<RoleOptionResponse> {
  RoleProvider() : super('Roles');

  @override
  RoleOptionResponse fromJson(Map<String, dynamic> json) =>
      RoleOptionResponse.fromJson(json);

  Future<List<RoleOptionResponse>> getAll() async {
    final json = await getAction(null);
    return ((json as List?) ?? [])
        .map((e) => RoleOptionResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
