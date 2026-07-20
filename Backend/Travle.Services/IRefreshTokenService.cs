using Travle.Services.Database;

namespace Travle.Services
{
    public interface IRefreshTokenService
    {
        /// <summary>Finds a non-revoked token by its stored hash (tracked, so it can be rotated). Expiry is judged by the caller.</summary>
        Task<RefreshToken?> GetActiveByHashAsync(string tokenHash);

        /// <summary>Persists a newly issued refresh token (login).</summary>
        Task AddAsync(RefreshToken token);

        /// <summary>Rotation: revokes the presented token and stores its replacement in one transaction.</summary>
        Task RotateAsync(RefreshToken current, RefreshToken replacement);

        /// <summary>Deletes every refresh token for a user (logout / suspension — server-side invalidation).</summary>
        Task DeleteAllForUserAsync(int userId);
    }
}
