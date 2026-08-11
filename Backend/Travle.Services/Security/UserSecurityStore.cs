using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace Travle.Services.Security
{
    /// <summary>The security-relevant slice of an account the token gate needs on every request: the
    /// current <see cref="SecurityStamp"/> (compared to the token's claim) and whether the account is
    /// suspended.</summary>
    public sealed record UserSecurityState(string SecurityStamp, bool IsSuspended);

    /// <summary>
    /// Read-through cache of each user's <see cref="UserSecurityState"/>, backing the JwtBearer
    /// <c>OnTokenValidated</c> gate. The gate runs on every authenticated request, so the two tiny
    /// values are cached in <see cref="IMemoryCache"/> (§8.2 — cache per-request static data) rather
    /// than hitting the DB each time; any auth change calls <see cref="Invalidate"/> so the next request
    /// re-reads the fresh state. It stores state, never tokens. See docs/auth-token-invalidation.md.
    /// </summary>
    public interface IUserSecurityStore
    {
        /// <summary>The user's current stamp + suspension flag, or null if no such user.</summary>
        Task<UserSecurityState?> GetAsync(int userId, CancellationToken cancellationToken = default);

        /// <summary>Drop the cached entry so the next <see cref="GetAsync"/> re-reads from the DB.
        /// Call after any change to the user's stamp or suspension state.</summary>
        void Invalidate(int userId);
    }

    public sealed class UserSecurityStore : IUserSecurityStore
    {
        // Short TTL is a backstop only — every auth change evicts the entry explicitly, so a change is
        // reflected on the very next request, not after the TTL.
        private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(2);

        private readonly TravleDbContext _dbContext;
        private readonly IMemoryCache _cache;

        public UserSecurityStore(TravleDbContext dbContext, IMemoryCache cache)
        {
            _dbContext = dbContext;
            _cache = cache;
        }

        private static string CacheKey(int userId) => $"user-security:{userId}";

        public async Task<UserSecurityState?> GetAsync(int userId, CancellationToken cancellationToken = default)
        {
            if (_cache.TryGetValue(CacheKey(userId), out UserSecurityState? cached))
            {
                return cached;
            }

            var state = await _dbContext.Users
                .AsNoTracking()
                .Where(u => u.Id == userId)
                .Select(u => new UserSecurityState(u.SecurityStamp, u.IsSuspended))
                .FirstOrDefaultAsync(cancellationToken);

            // Cache only real users, so a token for a not-yet-existing/deleted id isn't pinned.
            if (state is not null)
            {
                _cache.Set(CacheKey(userId), state, CacheTtl);
            }

            return state;
        }

        public void Invalidate(int userId) => _cache.Remove(CacheKey(userId));
    }
}
