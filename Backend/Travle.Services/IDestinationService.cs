using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Destinations: curators/organizers submit, admins moderate, travelers browse. The CRUD verbs
    /// carry domain logic — <c>Insert</c> is a curator/organizer submission (owner from the JWT, always
    /// Pending, images thumbnailed), <c>Update</c> sends the destination back to Pending, and
    /// <c>Delete</c> is allowed only while Pending and unreferenced. The extra reads split the three
    /// audiences (public search / my submissions / moderation queue) and the moderation actions carry
    /// the audit trail + notifications.
    /// </summary>
    public interface IDestinationService
        : IBaseCRUDService<DestinationResponse, DestinationSearch, DestinationInsertRequest, DestinationUpdateRequest>
    {
        /// <summary>Public, approved-only search; a text term writes a Search interaction for the JWT user.</summary>
        Task<PageResult<DestinationResponse>> SearchAsync(DestinationSearch? search);

        /// <summary>
        /// Search-autocomplete typeahead over the approved catalogue: a capped, best-rated-first list of
        /// name matches for the partial <paramref name="text"/>, accent-aware ("Poc" matches "Počitelj").
        /// A term shorter than the minimum length yields an empty list rather than an error (a typeahead
        /// probes as the user types). Records no interaction — the real <c>Search</c> signal is written when
        /// the user submits the full search from a suggestion.
        /// </summary>
        Task<List<DestinationSuggestionResponse>> GetSuggestionsAsync(string? text);

        /// <summary>
        /// Light, approved-only markers within a visible bounding box for the mobile map screen: only the
        /// fields needed to drop a pin and render its mini card, capped server-side and best-rated first.
        /// Optional multi-category + minimum-rating filters mirror the search screen. Records no interaction
        /// (a pan-heavy browse surface would flood the recommender diary).
        /// </summary>
        Task<List<DestinationMapPinResponse>> GetMapPinsAsync(DestinationMapSearch search);

        /// <summary>The current curator/organizer's own destinations (any status), paginated.</summary>
        Task<PageResult<DestinationResponse>> GetMineAsync(DestinationSearch? search);

        /// <summary>Admin moderation queue (defaults to Pending), paginated.</summary>
        Task<PageResult<DestinationResponse>> GetModerationQueueAsync(DestinationSearch? search);

        /// <summary>
        /// Detail read. When the destination is Approved and the caller is not its submitter, this also
        /// increments <c>ViewCount</c> and records a View interaction (recommender fuel).
        /// </summary>
        Task<DestinationResponse> GetDetailAsync(int id);

        /// <summary>Admin approves a pending destination: publishes it, records audit, notifies the submitter.</summary>
        Task<DestinationResponse> ApproveAsync(int id);

        /// <summary>Admin rejects a pending destination with a mandatory reason; records audit + notifies.</summary>
        Task<DestinationResponse> RejectAsync(int id, DestinationRejectRequest request);

        /// <summary>Admin toggles the featured flag (only an approved destination may be featured).</summary>
        Task<DestinationResponse> SetFeaturedAsync(int id, bool isFeatured);

        /// <summary>
        /// Full image bytes + content type. Throws <c>NotFoundException</c> when the image does not exist.
        /// Approved images are readable by any authenticated user; pending/rejected images only by the
        /// submitter or admin.
        /// </summary>
        Task<(byte[] Content, string ContentType)> GetImageAsync(int destinationId, int imageId);
    }
}
