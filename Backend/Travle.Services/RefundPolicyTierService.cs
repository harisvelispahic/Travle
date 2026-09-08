using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Payments;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

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

        // Every write is validated against the ladder it would produce, not just the row it touches. The
        // per-row validators check that a tier is sane in isolation (non-negative, max above min, 0–100%);
        // these hooks check the only thing that actually decides a refund — that the resulting tiers still
        // cover every hour before departure exactly once. See RefundPolicyLadder.
        //
        // No FK points at a tier (refunds snapshot PercentageApplied), so historical refunds are never
        // disturbed by an edit here; what is at stake is the correctness of future ones.

        protected override async Task OnBeforeInsertAsync(RefundPolicyTierInsertRequest request, RefundPolicyTier entity)
            => RefundPolicyLadder.EnsureContiguous([.. await OtherTiersAsync(), entity]);

        protected override async Task OnBeforeUpdateAsync(int id, RefundPolicyTierUpdateRequest request, RefundPolicyTier entity)
            // Built from the request, not the tracked entity: the hook runs before the update is mapped, so
            // the entity still holds its pre-edit values.
            => RefundPolicyLadder.EnsureContiguous([.. await OtherTiersAsync(id), new RefundPolicyTier
            {
                HoursBeforeMin = request.HoursBeforeMin,
                HoursBeforeMax = request.HoursBeforeMax,
                Percentage = request.Percentage
            }]);

        protected override async Task OnBeforeDeleteAsync(RefundPolicyTier entity)
            => RefundPolicyLadder.EnsureContiguous(await OtherTiersAsync(entity.Id));

        // The ladder as it stands, minus the row being changed. Untracked so it can never collide with the
        // tracked entity the CRUD base is about to mutate.
        private async Task<List<RefundPolicyTier>> OtherTiersAsync(int? excludingId = null)
            => await _dbContext.RefundPolicyTiers
                .AsNoTracking()
                .Where(t => excludingId == null || t.Id != excludingId)
                .ToListAsync();
    }
}
