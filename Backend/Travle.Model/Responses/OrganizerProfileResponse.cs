namespace Travle.Model.Responses
{
    /// <summary>
    /// A public, traveler-facing view of a tour organizer, shown when a traveler is deciding whether to
    /// book one of their tours. Deliberately omits contact details (email/phone) — bookings stay in-app.
    /// The rating is <b>computed on read</b> from the organizer's tour reviews (never a stored column),
    /// matching the tour-rating rule (03 §4): removed reviews and reviews by suspended users are excluded.
    /// Only the small avatar <see cref="ProfileImageThumbnail"/> carries bytes (§8.2) — the full profile
    /// image never travels here.
    /// </summary>
    public class OrganizerProfileResponse
    {
        public int Id { get; set; }

        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;

        /// <summary>Optional home city name (never a raw id on screen).</summary>
        public string? CityName { get; set; }

        /// <summary>When the organizer joined Travle (their account creation time).</summary>
        public DateTime MemberSince { get; set; }

        /// <summary>Small avatar thumbnail (JPEG); the only image bytes shipped here (§8.2).</summary>
        public byte[]? ProfileImageThumbnail { get; set; }

        /// <summary>Number of the organizer's active, publicly-visible tours.</summary>
        public int TourCount { get; set; }

        /// <summary>Average across all of the organizer's tour reviews (0 when none). Computed on read.</summary>
        public double AverageRating { get; set; }

        /// <summary>Number of non-removed reviews (by non-suspended users) behind <see cref="AverageRating"/>.</summary>
        public int ReviewCount { get; set; }

        /// <summary>A few of the organizer's best-rated active tours, as a preview into their catalogue.</summary>
        public List<TourResponse> TopTours { get; set; } = new List<TourResponse>();
    }
}
