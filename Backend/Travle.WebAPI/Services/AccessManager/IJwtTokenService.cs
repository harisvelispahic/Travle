using Travle.Model.Responses;

namespace Travle.WebAPI.Services.AccessManager
{
    /// <summary>A freshly issued access + refresh token pair. The raw refresh token is returned to
    /// the client; only its hash is persisted.</summary>
    public sealed class JwtTokenPair
    {
        public required string AccessToken { get; init; }
        public required DateTime AccessTokenExpiresAt { get; init; }
        public required string RefreshTokenRaw { get; init; }
        public required string RefreshTokenHash { get; init; }
        public required DateTime RefreshTokenExpiresAt { get; init; }
    }

    public interface IJwtTokenService
    {
        /// <summary>Issues a signed access token (with one role claim per role) plus a new refresh token.</summary>
        JwtTokenPair IssueTokens(UserResponse user);

        /// <summary>Hashes a raw refresh token the way stored tokens are hashed, for lookup/comparison.</summary>
        string HashRefreshToken(string rawToken);
    }
}
