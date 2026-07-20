namespace Travle.Model.Access
{
    /// <summary>
    /// Result of a successful login or token refresh. The refresh token is the raw value (stored
    /// only as a hash server-side); the access-token expiry lets the client refresh pre-emptively.
    /// </summary>
    public class UserLoginResponse
    {
        public string AccessToken { get; set; } = string.Empty;
        public DateTime AccessTokenExpiresAt { get; set; }
        public string RefreshToken { get; set; } = string.Empty;
        public DateTime RefreshTokenExpiresAt { get; set; }
    }
}
