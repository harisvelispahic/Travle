using Travle.Model.Responses;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class RoleService : IRoleService
    {
        private readonly TravleDbContext _dbContext;

        public RoleService(TravleDbContext dbContext)
        {
            _dbContext = dbContext;
        }

        // Only four fixed rows, so this returns the whole set (id + name) unpaged — it feeds a dropdown.
        public async Task<List<RoleOptionResponse>> GetAllAsync()
            => await _dbContext.Roles
                   .AsNoTracking()
                   .OrderBy(r => r.Name)
                   .Select(r => new RoleOptionResponse { Id = r.Id, Name = r.Name })
                   .ToListAsync();
    }
}
