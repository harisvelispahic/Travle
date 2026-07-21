using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using FluentValidation;

namespace Travle.Services
{
    public class RefundPolicyTierService
        : ReferenceCrudService<RefundPolicyTier, RefundPolicyTierResponse, RefundPolicyTierSearch, RefundPolicyTierInsertRequest, RefundPolicyTierUpdateRequest>,
          IRefundPolicyTierService
    {
        public RefundPolicyTierService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<RefundPolicyTierInsertRequest> insertValidator,
            IValidator<RefundPolicyTierUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
        }

        protected override IQueryable<RefundPolicyTier> ApplyFilters(IQueryable<RefundPolicyTier> query, RefundPolicyTierSearch? search)
        {
            if (search?.Percentage.HasValue == true)
            {
                query = query.Where(t => t.Percentage == search.Percentage.Value);
            }

            return query;
        }

        // No delete guard: no FK points at a tier (refunds snapshot PercentageApplied), so tiers are
        // freely editable/deletable without corrupting historical refunds (03 §3).
    }
}
