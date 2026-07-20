using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class RefreshTokenService : IRefreshTokenService
    {
        private readonly TravleDbContext _dbContext;

        public RefreshTokenService(TravleDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public Task<RefreshToken?> GetActiveByHashAsync(string tokenHash)
            => _dbContext.RefreshTokens.FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash && !rt.IsRevoked);

        public async Task AddAsync(RefreshToken token)
        {
            _dbContext.RefreshTokens.Add(token);
            await _dbContext.SaveChangesAsync();
        }

        public async Task RotateAsync(RefreshToken current, RefreshToken replacement)
        {
            current.IsRevoked = true;
            current.RevokedAt = DateTime.UtcNow;
            _dbContext.RefreshTokens.Add(replacement);

            // Revoke + insert in a single SaveChanges → one implicit transaction.
            await _dbContext.SaveChangesAsync();
        }

        public async Task DeleteAllForUserAsync(int userId)
        {
            _dbContext.RefreshTokens.RemoveRange(_dbContext.RefreshTokens.Where(rt => rt.UserId == userId));
            await _dbContext.SaveChangesAsync();
        }
    }
}
