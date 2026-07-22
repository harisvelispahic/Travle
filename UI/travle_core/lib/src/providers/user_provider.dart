import '../models/user_onboarding_request.dart';
import '../models/user_response.dart';
import '../network/base_provider.dart';

/// User self-service endpoints (`/Users`). Onboarding is Traveler-only; profile
/// edit and password change (added with their screens) are self-or-admin.
class UserProvider extends BaseProvider<UserResponse> {
  UserProvider() : super('Users');

  @override
  UserResponse fromJson(Map<String, dynamic> json) =>
      UserResponse.fromJson(json);

  /// Submits the onboarding interest picks. Returns the updated (onboarded) user.
  Future<UserResponse> completeOnboarding(UserOnboardingRequest request) async {
    final json = await postAction('onboarding-interests', request.toJson());
    return fromJson(json as Map<String, dynamic>);
  }

  /// Records that the onboarding step was shown (per-display prompt cap).
  /// Returns the updated user (its `onboardingPromptCount` incremented, and
  /// `isOnboarded` flipped once the cap is reached).
  Future<UserResponse> registerOnboardingPrompt() async {
    final json = await postAction('onboarding-prompt');
    return fromJson(json as Map<String, dynamic>);
  }
}
