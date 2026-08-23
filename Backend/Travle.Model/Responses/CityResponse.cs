namespace Travle.Model.Responses
{
    public class CityResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int RegionId { get; set; }
        /// <summary>Flattened from Region.Name by Mapster when the parent is included.</summary>
        public string? RegionName { get; set; }
        /// <summary>IANA time-zone id (e.g. "Europe/Sarajevo") — the zone the city's destinations' event times display in.</summary>
        public string TimeZoneId { get; set; } = string.Empty;

        /// <summary>
        /// How many other records still reference this row. Zero means it can be deleted.
        /// </summary>
        public int UsageCount { get; set; }

        /// <summary>
        /// Why this row cannot be deleted, or <c>null</c> when it can. Lets a client render Delete
        /// <b>disabled with the reason shown</b> instead of only failing on click (course §6). The same
        /// sentence is what the service throws as a <c>ConflictException</c> if a delete is attempted
        /// anyway, so the two can never drift.
        /// </summary>
        public string? DeleteBlockedReason { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
