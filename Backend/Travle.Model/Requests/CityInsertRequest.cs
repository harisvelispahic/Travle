namespace Travle.Model.Requests
{
    public class CityInsertRequest
    {
        public string Name { get; set; } = string.Empty;
        public int RegionId { get; set; }

        /// <summary>
        /// Optional IANA time-zone id (e.g. "Europe/Sarajevo"). When blank, the city inherits the platform
        /// default zone. When provided, it must be a real IANA identifier (validated server-side).
        /// </summary>
        public string? TimeZoneId { get; set; }
    }
}
