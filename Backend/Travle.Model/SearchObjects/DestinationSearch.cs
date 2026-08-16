namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for the destination list endpoints. The public search forces <c>Status = Approved</c>
    /// and ignores <see cref="Status"/>/<see cref="SubmittedByUserId"/>; the "my destinations" and
    /// moderation-queue paths set those server-side. Reference filters are FK ids, never strings.
    /// </summary>
    public class DestinationSearch : BaseSearchObject
    {
        /// <summary>Free-text match over name and description (accent-insensitive).</summary>
        public string? Text { get; set; }

        public int? CategoryId { get; set; }

        /// <summary>Filter by country (matched through the destination's city → region → country).</summary>
        public int? CountryId { get; set; }

        /// <summary>Filter by region (matched through the destination's city).</summary>
        public int? RegionId { get; set; }

        public int? CityId { get; set; }

        /// <summary>Minimum average rating (inclusive).</summary>
        public double? MinRating { get; set; }

        /// <summary>
        /// Moderation status: 0 = Pending, 1 = Approved, 2 = Rejected (matches DestinationStatus). Kept
        /// as an int so the Model layer stays free of the entity enum in Travle.Services.
        /// </summary>
        public int? Status { get; set; }

        /// <summary>Filter by submitter (used internally to scope a curator to their own destinations).</summary>
        public int? SubmittedByUserId { get; set; }

        public bool? IsFeatured { get; set; }
    }
}
