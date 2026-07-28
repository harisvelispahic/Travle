using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Tour reviews: gated to the reviewer's own <b>Completed</b> booking, one review per booking. The author
    /// may edit or self-remove their own; after a self-removal they may review that booking again (the removed
    /// row is reactivated). Admins moderate (soft-remove with a reason + notification), which is final — an
    /// admin-removed review can't be re-created. Organizers read the reviews across their own tours. Tour
    /// ratings are computed on read, so there is nothing to recompute here, and — by design — a tour review
    /// records no recommender interaction (the feature space is destination-based).
    /// </summary>
    public interface ITourReviewService : IBaseReadService<TourReviewResponse, TourReviewSearch>
    {
        /// <summary>Creates a review for the current user's Completed booking (one per booking). If the author
        /// previously self-removed their review for this booking, that row is reactivated.</summary>
        Task<TourReviewResponse> CreateAsync(TourReviewInsertRequest request);

        /// <summary>Author edits their own review (rating/comment).</summary>
        Task<TourReviewResponse> UpdateAsync(int id, TourReviewUpdateRequest request);

        /// <summary>Author soft-removes their own review; they may review the booking again afterwards.</summary>
        Task RemoveOwnAsync(int id);

        /// <summary>Reviews across the current organizer's own tours (their "reviews of my tours" view).</summary>
        Task<PageResult<TourReviewResponse>> GetForMyToursAsync(TourReviewSearch? search);

        /// <summary>Admin soft-removes any review with a mandatory reason (audit + author notification).</summary>
        Task<TourReviewResponse> RemoveAsync(int id, ReviewRemoveRequest request);
    }
}
