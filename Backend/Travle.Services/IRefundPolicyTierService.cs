using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IRefundPolicyTierService
        : IBaseCRUDService<RefundPolicyTierResponse, RefundPolicyTierSearch, RefundPolicyTierInsertRequest, RefundPolicyTierUpdateRequest>
    {
        /// <summary>
        /// Replaces the entire refund ladder in one transaction. The tiers are only valid as a set — every
        /// hour before departure covered exactly once, refunds rising with notice — so this is the editing
        /// unit the admin console uses. The per-row CRUD verbs remain (and enforce the same rule), but they
        /// can only ever make edits that keep an already-valid ladder valid, which in practice means almost
        /// none: a ladder that tiles the range has no room for another row.
        /// </summary>
        Task<List<RefundPolicyTierResponse>> ReplaceLadderAsync(RefundPolicyLadderRequest request);
    }
}
