using Travle.Model.Constants;
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
        // The base keeps its own copy for the CRUD verbs; the ladder replacement is a verb of this service's
        // own, so it holds the authorization boundary and its validator directly.
        private readonly IAppAuthorizationService _authorization;
        private readonly IValidator<RefundPolicyLadderRequest> _ladderValidator;

        public RefundPolicyTierService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<RefundPolicyTierInsertRequest> insertValidator,
            IValidator<RefundPolicyTierUpdateRequest> updateValidator,
            IValidator<RefundPolicyLadderRequest> ladderValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
            _authorization = authorization;
            _ladderValidator = ladderValidator;
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

        /// <summary>
        /// Replaces the whole ladder in one transaction. Validated as a set first, so the database never
        /// briefly holds an invalid policy and a rejected edit changes nothing at all.
        ///
        /// The rows are replaced rather than reconciled: no foreign key points at a tier — refunds snapshot
        /// the percentage they applied, and since the August review the booking snapshots the amount it
        /// owes — so a tier carries no history worth preserving through an edit, and matching old rows to
        /// new ones would only invent an identity the ladder does not have.
        /// </summary>
        public async Task<List<RefundPolicyTierResponse>> ReplaceLadderAsync(RefundPolicyLadderRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            await _ladderValidator.ValidateAndThrowAsync(request);

            var replacement = request.Tiers
                .Select(t => new RefundPolicyTier
                {
                    HoursBeforeMin = t.HoursBeforeMin,
                    HoursBeforeMax = t.HoursBeforeMax,
                    Percentage = t.Percentage
                })
                .ToList();

            RefundPolicyLadder.EnsureContiguous(replacement);

            await using var transaction = await _dbContext.Database.BeginTransactionAsync();

            _dbContext.RefundPolicyTiers.RemoveRange(await _dbContext.RefundPolicyTiers.ToListAsync());
            await _dbContext.SaveChangesAsync();

            _dbContext.RefundPolicyTiers.AddRange(replacement);
            await _dbContext.SaveChangesAsync();

            await transaction.CommitAsync();

            return replacement
                .OrderByDescending(t => t.HoursBeforeMin)
                .Select(_mapper.Map<RefundPolicyTierResponse>)
                .ToList();
        }

        // The ladder as it stands, minus the row being changed. Untracked so it can never collide with the
        // tracked entity the CRUD base is about to mutate.
        private async Task<List<RefundPolicyTier>> OtherTiersAsync(int? excludingId = null)
            => await _dbContext.RefundPolicyTiers
                .AsNoTracking()
                .Where(t => excludingId == null || t.Id != excludingId)
                .ToListAsync();
    }
}
