namespace Travle.Model.Responses
{
    /// <summary>
    /// A bookable tour, in the single shape used by every read path — the paginated list, the "tours
    /// visiting a destination" section, and the detail view. Reference fields are flattened to names
    /// (never raw ids on screen). Only <see cref="PrimaryThumbnail"/> carries bytes on the list path
    /// (the ordered-first destination's thumbnail, reused as the tour cover — tours have no images of
    /// their own); <see cref="Destinations"/> and <see cref="Schedules"/> are populated on the detail
    /// path only, so list payloads stay light (§8.2 / rule 12).
    /// </summary>
    public class TourResponse
    {
        public int Id { get; set; }

        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public int DurationMinutes { get; set; }
        public decimal PricePerPerson { get; set; }

        /// <summary>
        /// Sum of the visited destinations' informative entrance fees (KM), <b>per person</b> — money the
        /// traveler pays on-site, never part of the Travle charge. 0 when no stop has a fee. Shown as a
        /// "bring around X" guide, not an authoritative total.
        /// </summary>
        public decimal EntranceFeesPerPerson { get; set; }

        /// <summary>Default group size seeded into new schedules; each slot may override it.</summary>
        public int Capacity { get; set; }

        public int TourTypeId { get; set; }
        public string? TourTypeName { get; set; }

        public int OrganizerId { get; set; }
        public string? OrganizerName { get; set; }

        public bool IsActive { get; set; }

        /// <summary>Number of destinations this tour visits (shown on cards without loading the stops).</summary>
        public int DestinationCount { get; set; }

        /// <summary>Count of Active, future schedules (a "sold-out"/"no upcoming dates" hint on cards).</summary>
        public int UpcomingScheduleCount { get; set; }

        /// <summary>Start of the next Active, future schedule, if any (for a "next departure" chip).</summary>
        public DateTime? NextDepartureAt { get; set; }

        /// <summary>The ordered-first destination's thumbnail, used as the tour cover on list cards.</summary>
        public byte[]? PrimaryThumbnail { get; set; }
        public string? PrimaryThumbnailContentType { get; set; }

        /// <summary>Ordered stops the tour visits. Populated on the detail read only (empty in lists).</summary>
        public List<TourDestinationRef> Destinations { get; set; } = new List<TourDestinationRef>();

        /// <summary>Upcoming Active schedules with live free-seat counts. Detail read only (null in lists).</summary>
        public List<TourScheduleResponse>? Schedules { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
