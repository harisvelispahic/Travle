using Travle.Model.Constants;

namespace Travle.Services.Database
{
    /// <summary>Reference table. A city belongs to a <see cref="Region"/> and locates a <see cref="Destination"/>.</summary>
    public class City : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public int RegionId { get; set; }
        public Region Region { get; set; } = null!;

        /// <summary>
        /// IANA time-zone identifier for this city (e.g. <c>Europe/Sarajevo</c>). A tour's schedule times
        /// are stored as UTC instants and displayed in the zone of the tour's (ordered-first) destination,
        /// which resolves here through <see cref="Destination.City"/>. Always populated — defaults to the
        /// platform zone (<see cref="TimeDefaults.PlatformTimeZoneId"/>) for BiH cities.
        /// See docs/time-and-timezones.md.
        /// </summary>
        public string TimeZoneId { get; set; } = TimeDefaults.PlatformTimeZoneId;

        public ICollection<Destination> Destinations { get; set; } = new List<Destination>();
    }
}
