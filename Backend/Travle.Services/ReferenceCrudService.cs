using System.Linq.Expressions;
using Travle.Model.Constants;
using Travle.Model.Responses;
using Microsoft.EntityFrameworkCore;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using FluentValidation;

namespace Travle.Services
{
    /// <summary>
    /// CRUD base for admin-managed reference data (03 §7 / spec §2.4). All writes require the Admin
    /// role, enforced here so the service is its own authorization boundary — the check holds even if a
    /// write is reached from somewhere other than the Admin-gated controller. Reads are inherited
    /// unchanged (gated to an authenticated user at the controller). Concrete services keep overriding
    /// the <c>OnBefore*</c> hooks for their FK/uniqueness rules.
    /// </summary>
    public abstract class ReferenceCrudService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseCRUDService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        private readonly IAppAuthorizationService _authorization;

        protected ReferenceCrudService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<TInsertRequest> insertValidator,
            IValidator<TUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _authorization = authorization;
        }

        /// <summary>
        /// Paged read that projects straight to the response in SQL instead of materialising entities and
        /// mapping them. Reference lists use it so each row can carry its <c>UsageCount</c> (a correlated
        /// COUNT, still one query) and, after materialisation, the <c>DeleteBlockedReason</c> the desktop
        /// needs to render Delete disabled-with-a-reason. Filtering, sorting and the page-size cap all come
        /// from the shared base, so behaviour stays identical to <see cref="BaseReadService{TEntity,
        /// TResponse, TSearch}.GetAllAsync"/>.
        /// </summary>
        protected async Task<PageResult<TResponse>> GetPageAsync(
            TSearch? search,
            Expression<Func<TEntity, TResponse>> projection,
            Action<TResponse>? finalize = null)
        {
            IQueryable<TEntity> query = _dbContext.Set<TEntity>().AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await query.Select(projection).ToListAsync();
            if (finalize is not null)
            {
                foreach (var item in items)
                {
                    finalize(item);
                }
            }

            return new PageResult<TResponse> { Items = items, TotalCount = totalCount };
        }

        public override Task<TResponse> InsertAsync(TInsertRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            return base.InsertAsync(request);
        }

        public override Task<TResponse> UpdateAsync(int id, TUpdateRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            return base.UpdateAsync(id, request);
        }

        public override Task DeleteAsync(int id)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            return base.DeleteAsync(id);
        }
    }
}
