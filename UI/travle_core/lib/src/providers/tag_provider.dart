import '../models/tag_response.dart';
import '../network/base_provider.dart';

/// Reads tags (`GET /Tags`). Reads require an authenticated user; writes are
/// admin-only (desktop reference CRUD).
class TagProvider extends BaseProvider<TagResponse> {
  TagProvider() : super('Tags');

  @override
  TagResponse fromJson(Map<String, dynamic> json) => TagResponse.fromJson(json);
}
