using Travle.Model.Access;
using Travle.Model.Exceptions;
using Travle.Services;
using Travle.Services.Database;

namespace Travle.WebAPI.Services.AccessManager
{
    public class AccessManager : IAccessManager
    {
        private readonly IUserService _userService;
        private readonly IJwtTokenService _jwtTokenService;
        private readonly IRefreshTokenService _refreshTokenService;

        public AccessManager(
            IUserService userService,
            IJwtTokenService jwtTokenService,
            IRefreshTokenService refreshTokenService)
        {
            _userService = userService;
            _jwtTokenService = jwtTokenService;
            _refreshTokenService = refreshTokenService;
        }

        public async Task<UserLoginResponse> LoginAsync(UserLoginRequest request)
        {
            var user = await _userService.ValidateCredentialsAsync(request.Username, request.Password);

            // Same message for unknown username and wrong password — no account enumeration.
            if (user is null)
            {
                throw new UnauthorizedException("Invalid username or password.");
            }

            EnsureNotSuspended(user.IsSuspended);

            var pair = _jwtTokenService.IssueTokens(user);
            await _refreshTokenService.AddAsync(BuildStoredToken(pair, user.Id));

            return BuildResponse(pair);
        }

        public async Task<UserLoginResponse> RefreshAsync(RefreshAccessTokenRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                throw new UnauthorizedException("Refresh token is invalid or has expired.");
            }

            var incomingHash = _jwtTokenService.HashRefreshToken(request.RefreshToken);
            var stored = await _refreshTokenService.GetActiveByHashAsync(incomingHash);

            if (stored is null || stored.ExpiresAt <= DateTime.UtcNow)
            {
                throw new UnauthorizedException("Refresh token is invalid or has expired.");
            }

            var user = await _userService.GetWithRolesByIdAsync(stored.UserId)
                ?? throw new UnauthorizedException("Refresh token is invalid or has expired.");

            EnsureNotSuspended(user.IsSuspended);

            var pair = _jwtTokenService.IssueTokens(user);
            await _refreshTokenService.RotateAsync(stored, BuildStoredToken(pair, user.Id));

            return BuildResponse(pair);
        }

        public Task LogoutAsync(int userId) => _refreshTokenService.DeleteAllForUserAsync(userId);

        private static void EnsureNotSuspended(bool isSuspended)
        {
            if (isSuspended)
            {
                throw new ForbiddenException("This account has been suspended.");
            }
        }

        private static RefreshToken BuildStoredToken(JwtTokenPair pair, int userId) => new()
        {
            TokenHash = pair.RefreshTokenHash,
            ExpiresAt = pair.RefreshTokenExpiresAt,
            UserId = userId
        };

        private static UserLoginResponse BuildResponse(JwtTokenPair pair) => new()
        {
            AccessToken = pair.AccessToken,
            AccessTokenExpiresAt = pair.AccessTokenExpiresAt,
            RefreshToken = pair.RefreshTokenRaw,
            RefreshTokenExpiresAt = pair.RefreshTokenExpiresAt
        };
    }
}
