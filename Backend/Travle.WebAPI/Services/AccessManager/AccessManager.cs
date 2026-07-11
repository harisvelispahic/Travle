using Travle.Common.Services.CryptoService;
using Travle.Model.Access;
using Travle.Model.Exceptions;
using Travle.Model.Responses;
using Travle.Services;
using Travle.Services.Database;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace Travle.WebAPI.Services.AccessManager
{
    public class AccessManager : IAccessManager
    {
        private readonly IUserService _userService;
        private readonly IConfiguration _configuration;
        private readonly ICryptoService _cryptoService;
        private readonly IRefreshTokenService _refreshTokenService;

        public AccessManager(IUserService userService, IConfiguration configuration, ICryptoService cryptoService, IRefreshTokenService refreshTokenService)
        {
            _userService = userService;
            _configuration = configuration;
            _cryptoService = cryptoService;
            _refreshTokenService = refreshTokenService;
        }

        public async Task<UserLoginResponse> LoginAsync(UserLoginRequest request)
        {
            var user = await _userService.GetByUsernameAsync(request.Username);


            if (user == null)
            {
                throw new Exception($"User with {request.Username} doesn't exist");
            }

            var validPassword = _cryptoService.Verify(user.PasswordHash, user.PasswordSalt, request.Password);
            if (!validPassword)
            {
                throw new Exception("Wrong credential");
            }

            var accessToken = GenerateToken(user);
            var refreshTokenValue = GenerateRefreshToken();

            var refreshToken = new RefreshToken
            {
                UserId = user.Id,
                Token = refreshTokenValue,
                ExpiresAt = DateTime.UtcNow.AddDays(7)
            };

            await _refreshTokenService.InsertAsync(refreshToken);

            return new UserLoginResponse
            {
                Accesstoken = accessToken,
                Refreshtoken = refreshTokenValue
            };
        }

        public async Task<UserLoginResponse> LoginWithRefreshTokenAsync(RefreshAccessTokenRequest request)
        {
            if (string.IsNullOrEmpty(request.RefreshToken))
            {
                throw new ClientException("Refresh token is required");
            }

            var refreshToken = await _refreshTokenService.GetStoredTokenAsync(request.RefreshToken);

            if (refreshToken == null)
            {
                throw new ClientException("Invalid refresh token");
            }

            if (refreshToken.ExpiresAt < DateTime.UtcNow)
            {
                throw new ClientException("Refresh token has expired");
            }

            var user = await _userService.GetWithRoleByIdAsync(refreshToken.UserId);

            if (user == null)
            {
                throw new ClientException("User not found");
            }

            if (!user.IsActive)
            {
                throw new ClientException("User is not active");
            }

            await _refreshTokenService.DeleteAllUserRefreshTokensAsync(user.Id);

            var accessToken = GenerateToken(user);
            var refreshTokenValue = GenerateRefreshToken();

            var token = new RefreshToken
            {
                UserId = user.Id,
                Token = refreshTokenValue,
                ExpiresAt = DateTime.UtcNow.AddDays(7)
            };

            await _refreshTokenService.InsertAsync(token);

            return new UserLoginResponse
            {
                Accesstoken = accessToken,
                Refreshtoken = refreshTokenValue
            };

        }

        private string GenerateToken(UserResponse user)
        {
            string secretKeyString = _configuration["JwtToken:SecretKey"] ?? string.Empty;
            var issuer = _configuration["JwtToken:Issuer"];
            var audience = _configuration["JwtToken:Audience"];
            var durationInMinutes = int.Parse(_configuration["JwtToken:DurationInMinutes"] ?? "1");

            var secretKey = Encoding.ASCII.GetBytes(secretKeyString);

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimNames.Id, user.Id.ToString()),
                    new Claim(ClaimNames.FirstName, user.FirstName ?? string.Empty),
                    new Claim(ClaimNames.LastName, user.LastName ?? string.Empty),
                    new Claim(ClaimNames.Email, user.Email ?? string.Empty),
                    new Claim(ClaimNames.Role, user.Role ?? "user"),
                    new Claim(ClaimNames.IsActive, user.IsActive.ToString())
                }),
                Expires = DateTime.UtcNow.AddMinutes(durationInMinutes),
                Issuer = issuer,
                Audience = audience,
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(secretKey), SecurityAlgorithms.HmacSha256Signature)
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var token = tokenHandler.CreateToken(tokenDescriptor);

            return tokenHandler.WriteToken(token);
        }

        private static string GenerateRefreshToken()
        {
            var randombytes = RandomNumberGenerator.GetBytes(64);
            return Convert.ToBase64String(randombytes);
        }

       
    }
}
