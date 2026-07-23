import '../models/user_onboarding_request.dart';
import '../models/user_password_change_request.dart';
import '../models/user_response.dart';
import '../models/user_update_request.dart';
import '../network/base_provider.dart';

/// User self-service endpoints (`/Users`). Onboarding is Traveler-only; profile
/// edit and password change are self-or-admin (the server takes the acting user
/// from the JWT and enforces "self, or admin").
class UserProvider extends BaseProvider<UserResponse> {
  UserProvider() : super('Users');

  @override
  UserResponse fromJson(Map<String, dynamic> json) =>
      UserResponse.fromJson(json);

  /// Updates the profile (`PUT /Users/{id}`). Returns the updated user.
  Future<UserResponse> updateProfile(int id, UserUpdateRequest request) =>
      update(id, request.toJson());

  /// Changes the signed-in user's password (`POST /Users/ChangePassword`). The
  /// account comes from the JWT; the current password is verified server-side.
  Future<void> changePassword(UserPasswordChangeRequest request) async {
    await postAction('ChangePassword', request.toJson());
  }

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
