namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for tour reviews. <see cref="TourId"/> scopes to one tour's reviews; <see cref="OrganizerId"/>
    /// scopes to every review across an organizer's tours (their "reviews of my tours" view).
    /// <see cref="IncludeRemoved"/> is honored only for admins.
    /// </summary>
    public class TourReviewSearch : BaseSearchObject
    {
        /// <summary>
        /// Free text: the reviewed tour's name or the author's name/username (each word must land
        /// somewhere), so the moderation list has the search parameter every list view owes (course §2.2).
        /// </summary>
        public string? Text { get; set; }

        public int? TourId { get; set; }
        public int? OrganizerId { get; set; }
        public int? UserId { get; set; }
        public int? MinRating { get; set; }

        /// <summary>Admin moderation only: include soft-removed reviews (default false).</summary>
        public bool? IncludeRemoved { get; set; }
    }
}
