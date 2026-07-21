using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IUserService : IBaseReadService<UserResponse, UserSearch>
    {
        /// <summary>Self-service registration; always assigns the Traveler role.</summary>
        Task<UserResponse> RegisterAsync(UserRegisterRequest request);

        /// <summary>Profile edit. Caller must be the user themselves or an admin (checked from the JWT).</summary>
        Task<UserResponse> UpdateProfileAsync(int id, UserUpdateRequest request);

        /// <summary>Changes the current user's own password (user taken from the JWT).</summary>
        Task ChangePasswordAsync(UserPasswordChangeRequest request);

        /// <summary>Admin action: suspend a user and revoke their refresh tokens.</summary>
        Task<UserResponse> SuspendAsync(int id, UserSuspendRequest request);

        /// <summary>Admin action: lift a suspension.</summary>
        Task<UserResponse> UnsuspendAsync(int id);

        /// <summary>
        /// Records the current user's onboarding interest picks as OnboardingInterest interactions and
        /// marks them onboarded. Callable once; an empty request is a valid skip (04 §5).
        /// </summary>
        Task<UserResponse> CompleteOnboardingAsync(UserOnboardingRequest request);

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
