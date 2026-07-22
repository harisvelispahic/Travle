/// Shared client logic for the Travle apps: configuration, networking,
/// session/auth, and paging primitives. UI lives in `travle_ui`.
library;

export 'src/app_config.dart';
export 'src/models/destination_category_response.dart';
export 'src/models/forgot_password_request.dart';
export 'src/models/reset_password_request.dart';
export 'src/models/tag_response.dart';
export 'src/models/user_onboarding_request.dart';
export 'src/models/user_register_request.dart';
export 'src/models/user_response.dart';
export 'src/network/api_error.dart';
export 'src/network/search_result.dart';
export 'src/network/base_search_object.dart';
export 'src/network/base_provider.dart';
export 'src/providers/destination_category_provider.dart';
export 'src/providers/tag_provider.dart';
export 'src/providers/user_provider.dart';
export 'src/auth/app_role.dart';
export 'src/auth/auth_provider.dart';
