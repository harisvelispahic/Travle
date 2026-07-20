using Travle.Model.Responses;
using Travle.WebAPI.Options;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace Travle.WebAPI.Services.AccessManager
{
    public sealed class JwtTokenService : IJwtTokenService
    {
        private readonly JwtOptions _jwt;

        public JwtTokenService(IOptions<JwtOptions> options)
        {
            _jwt = options.Value;
        }

        public JwtTokenPair IssueTokens(UserResponse user)
        {
            var now = DateTime.UtcNow;
            var accessExpires = now.AddMinutes(_jwt.DurationInMinutes);
            var refreshExpires = now.AddDays(_jwt.RefreshTokenDays);

            var claims = new List<Claim>
            {
                new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new(ClaimTypes.Email, user.Email),
                new(ClaimTypes.Name, user.Username),
                new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
                new(JwtRegisteredClaimNames.Iat, new DateTimeOffset(now).ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64)
            };

            // One role claim per role — this is what makes multi-role accounts (Traveler + Curator)
            // and RequireRole-based policies work.
            claims.AddRange(user.Roles.Select(role => new Claim(ClaimTypes.Role, role)));

            var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SecretKey));
            var credentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: _jwt.Issuer,
                audience: _jwt.Audience,
                claims: claims,
                notBefore: now,
                expires: accessExpires,
                signingCredentials: credentials);

            var accessToken = new JwtSecurityTokenHandler().WriteToken(token);

            var refreshRaw = Base64UrlEncoder.Encode(RandomNumberGenerator.GetBytes(64));

            return new JwtTokenPair
            {
                AccessToken = accessToken,
                AccessTokenExpiresAt = accessExpires,
                RefreshTokenRaw = refreshRaw,
                RefreshTokenHash = HashRefreshToken(refreshRaw),
                RefreshTokenExpiresAt = refreshExpires
            };
        }

        public string HashRefreshToken(string rawToken)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(rawToken));
            return Base64UrlEncoder.Encode(bytes);
        }
    }
}
