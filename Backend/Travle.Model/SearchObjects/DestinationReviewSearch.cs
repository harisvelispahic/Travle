namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for destination reviews. <see cref="DestinationId"/> scopes to one destination's reviews
    /// (the common case). <see cref="IncludeRemoved"/> is honored only for admins — public reads never
    /// surface soft-removed rows regardless of this flag.
    /// </summary>
    public class DestinationReviewSearch : BaseSearchObject
    {
        /// <summary>
        /// Free text: the reviewed destination's name or the author's name/username (each word must land
        /// somewhere), so the moderation list has the search parameter every list view owes (course §2.2).
        /// </summary>
        public string? Text { get; set; }

        public int? DestinationId { get; set; }
        public int? UserId { get; set; }
        public int? MinRating { get; set; }

        /// <summary>Admin moderation only: include soft-removed reviews (default false).</summary>
        public bool? IncludeRemoved { get; set; }
    }
}
