using Travle.Model.Access;

namespace Travle.WebAPI.Services.AccessManager
{
    public interface IAccessManager
    {
        Task<UserLoginResponse> LoginAsync(UserLoginRequest request);
        Task<UserLoginResponse> RefreshAsync(RefreshAccessTokenRequest request);

        /// <summary>Server-side logout: deletes every refresh token for the user (course §J).</summary>
        Task LogoutAsync(int userId);
    }
}
