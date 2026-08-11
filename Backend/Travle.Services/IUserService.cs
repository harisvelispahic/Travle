using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IUserService : IBaseReadService<UserResponse, UserSearch>
    {
        /// <summary>Self-service registration; always assigns the Traveler role.</summary>
        Task<UserResponse> RegisterAsync(UserRegisterRequest request);

        /// <summary>
        /// Admin action: create an account with an admin-set password and any combination of roles
        /// (the only path to an Admin account). Distinct from <see cref="RegisterAsync"/>, which is the
        /// anonymous Traveler-only self-registration.
        /// </summary>
        Task<UserResponse> CreateAsync(AdminCreateUserRequest request);

        /// <summary>Admin action: grant a role to an existing user and revoke their refresh tokens.</summary>
        Task<UserResponse> GrantRoleAsync(int id, UserRoleGrantRequest request);

        /// <summary>
        /// Admin action: remove a role from an existing user and revoke their refresh tokens. Blocks
        /// removing the caller's own Admin role and removing the last remaining Admin.
        /// </summary>
        Task<UserResponse> RevokeRoleAsync(int id, int roleId);

        /// <summary>Profile edit. Caller must be the user themselves or an admin (checked from the JWT).</summary>
        Task<UserResponse> UpdateProfileAsync(int id, UserUpdateRequest request);

        /// <summary>Changes the current user's own password (user taken from the JWT).</summary>
        Task ChangePasswordAsync(UserPasswordChangeRequest request);

        /// <summary>Admin action: suspend a user and revoke their refresh tokens.</summary>
        Task<UserResponse> SuspendAsync(int id, UserSuspendRequest request);

        /// <summary>Admin action: lift a suspension.</summary>
        Task<UserResponse> UnsuspendAsync(int id);

        /// <summary>Ends every session for the user server-side: rolls the security stamp (so existing
        /// access tokens are rejected on their next request) and drops all refresh tokens, in one save.
        /// Used by logout. See docs/auth-token-invalidation.md.</summary>
        Task InvalidateAllSessionsAsync(int userId);

        /// <summary>
        /// Records the current traveler's onboarding interest picks as OnboardingInterest interactions
        /// and marks them onboarded. Idempotent: the display-prompt cap may have already set the flag
        /// before the picks arrive, so completing stays allowed but never duplicates interests.
        /// </summary>
        Task<UserResponse> CompleteOnboardingAsync(UserOnboardingRequest request);

        /// <summary>
        /// Records that the onboarding step was shown to the current traveler (increments the prompt
        /// count). When the count reaches the configured cap the user is marked onboarded so the step
        /// stops appearing. No-op once already onboarded.
        /// </summary>
        Task<UserResponse> RegisterOnboardingPromptAsync();

        /// <summary>
        /// Verifies a username/password pair for the login flow. Returns the user (with roles) on
        /// success or <c>null</c> on unknown user or wrong password — the hash/salt never leave the
        /// service. Suspension is not judged here; the caller decides.
        /// </summary>
        Task<UserResponse?> ValidateCredentialsAsync(string username, string password);

        /// <summary>Loads a user with their roles for the refresh/current-user flow.</summary>
        Task<UserResponse?> GetWithRolesByIdAsync(int id);
    }
}
