namespace Travle.Model.SearchObjects
{
    /// <summary>
    /// Filters for the tour list endpoints. The public browse forces <c>IsActive = true</c> and ignores
    /// <see cref="OrganizerId"/>; the "my tours" path scopes <see cref="OrganizerId"/> to the JWT user
    /// server-side. Reference filters are FK ids, never strings.
    /// </summary>
    public class TourSearch : BaseSearchObject
    {
        /// <summary>Free-text match over name and description (accent-insensitive).</summary>
        public string? Text { get; set; }

        public int? TourTypeId { get; set; }

        /// <summary>Filter by organizer (used internally to scope an organizer to their own tours).</summary>
        public int? OrganizerId { get; set; }

        /// <summary>Only tours whose itinerary includes this destination (the "tours visiting here" section).</summary>
        public int? DestinationId { get; set; }

        public bool? IsActive { get; set; }

        public decimal? MinPrice { get; set; }
        public decimal? MaxPrice { get; set; }

        /// <summary>When true, keep only tours that have at least one Active, future schedule.</summary>
        public bool? OnlyWithUpcomingSchedules { get; set; }

        /// <summary>
        /// When true, drop any tour that visits a non-approved destination (a stop pulled back into
        /// moderation). Forced on by the public browse in the service so travelers never reach a tour with
        /// an under-review stop; left off for the organizer's own list and the admin view.
        /// </summary>
        public bool? ExcludeUnavailableDestinations { get; set; }
    }
}
