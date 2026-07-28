using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Destination reviews: any registered user may leave one active review per destination (edit or
    /// remove their own), and admins moderate (soft-remove with a reason + notification). Every write that
    /// changes the set of active ratings recomputes the destination's denormalized <c>AverageRating</c>,
    /// and a 4–5★ review records a <c>ReviewHigh</c> interaction (recommender fuel). Removed reviews are
    /// excluded from public reads and from the average.
    /// </summary>
    public interface IDestinationReviewService : IBaseReadService<DestinationReviewResponse, DestinationReviewSearch>
    {
        /// <summary>Creates the current user's review of an approved destination (one active per destination).</summary>
        Task<DestinationReviewResponse> CreateAsync(DestinationReviewInsertRequest request);

        /// <summary>Author edits their own review (rating/comment); recomputes the destination average.</summary>
        Task<DestinationReviewResponse> UpdateAsync(int id, DestinationReviewUpdateRequest request);

        /// <summary>Author soft-removes their own review; recomputes the average. They may review again afterwards.</summary>
        Task RemoveOwnAsync(int id);

        /// <summary>Admin soft-removes any review with a mandatory reason (audit + author notification).</summary>
        Task<DestinationReviewResponse> RemoveAsync(int id, ReviewRemoveRequest request);
    }
}
