using Travle.Model.Exceptions;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Services
{
    public class RefreshTokenService : IRefreshTokenService
    {
        private readonly TravleDbContext _context;
        private readonly DbSet<RefreshToken> _refreshTokens;

        public RefreshTokenService(TravleDbContext context)
        {
            _context = context;
            _refreshTokens = _context.RefreshTokens;
        }

        public async Task<RefreshToken> GetStoredTokenAsync(string refreshToken)
        {
            var token = await _refreshTokens.FirstOrDefaultAsync(rt => rt.Token == refreshToken);

            if (token == null)
            {
                throw new ClientException("Refresh token not found.");
            }

            return token;
        }

        public async Task InsertAsync(RefreshToken refreshToken)
        {
            await _context.RefreshTokens.AddAsync(refreshToken);
            await _context.SaveChangesAsync();
        }

        public Task DeleteAllUserRefreshTokensAsync(int userId)
        {
            _refreshTokens.RemoveRange(_refreshTokens.Where(rt => rt.UserId == userId));
            return _context.SaveChangesAsync();
        }
    }
}
