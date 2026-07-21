using Travle.Model.Constants;
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
