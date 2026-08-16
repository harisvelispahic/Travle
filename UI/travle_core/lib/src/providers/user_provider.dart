import '../models/admin_create_user_request.dart';
import '../models/organizer_profile_response.dart';
import '../models/user_onboarding_request.dart';
import '../models/user_password_change_request.dart';
import '../models/user_response.dart';
import '../models/user_update_request.dart';
import '../network/base_provider.dart';

/// User endpoints (`/Users`). Self-service: onboarding (Traveler-only), profile
/// edit and password change (self-or-admin — the server takes the acting user
/// from the JWT). Admin-only: list/read, create, suspend/unsuspend, and role
/// grant/revoke (all enforced server-side).
class UserProvider extends BaseProvider<UserResponse> {
  UserProvider() : super('Users');

  @override
  UserResponse fromJson(Map<String, dynamic> json) =>
      UserResponse.fromJson(json);

  /// Updates the profile (`PUT /Users/{id}`). Returns the updated user.
  Future<UserResponse> updateProfile(int id, UserUpdateRequest request) =>
      update(id, request.toJson());

  /// A tour organizer's public profile (`GET /Users/{id}/organizer-profile`):
  /// name, home city, member-since, avatar, a computed average rating, and their
  /// top tours. Any authenticated user; the server 404s a non-organizer id.
  Future<OrganizerProfileResponse> organizerProfile(int id) async {
    final json = await getAction('$id/organizer-profile') as Map<String, dynamic>;
    return OrganizerProfileResponse.fromJson(json);
  }

  /// Admin: creates an account (`POST /Users`) with an admin-set password and any
  /// combination of roles. Returns the created user.
  Future<UserResponse> createUser(AdminCreateUserRequest request) =>
      insert(request.toJson());

  /// Admin: suspends a user (`POST /Users/{id}/Suspend`) with a mandatory reason.
  /// Returns the updated user.
  Future<UserResponse> suspend(int id, String reason) async {
    final json = await postAction('$id/Suspend', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: lifts a suspension (`POST /Users/{id}/Unsuspend`). Returns the user.
  Future<UserResponse> unsuspend(int id) async {
    final json = await postAction('$id/Unsuspend');
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: grants a role to a user (`POST /Users/{id}/Roles`). Returns the user.
  Future<UserResponse> grantRole(int id, int roleId) async {
    final json = await postAction('$id/Roles', {'roleId': roleId});
    return fromJson(json as Map<String, dynamic>);
  }

  /// Admin: removes a role from a user (`DELETE /Users/{id}/Roles/{roleId}`).
  /// Returns the updated user.
  Future<UserResponse> revokeRole(int id, int roleId) async {
    final json = await deleteActionJson('$id/Roles/$roleId');
    return fromJson(json as Map<String, dynamic>);
  }

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
