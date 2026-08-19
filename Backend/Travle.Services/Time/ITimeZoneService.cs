namespace Travle.Services.Time
{
    /// <summary>
    /// Converts between UTC instants and a destination's local wall-clock using the IANA time-zone
    /// database (bundled by NodaTime, so it works in any container without an OS <c>tzdata</c> package).
    /// Travle stores every timestamp as a UTC instant; a tour schedule's <b>event</b> times are entered by
    /// the organizer as wall-clock at the destination and displayed the same way. This service is the one
    /// place that knows how to bridge the two, DST included. See docs/time-and-timezones.md.
    /// </summary>
    public interface ITimeZoneService
    {
        /// <summary>The platform-wide fallback IANA zone (validated at startup).</summary>
        string PlatformTimeZoneId { get; }

        /// <summary>True when <paramref name="timeZoneId"/> is a real IANA identifier.</summary>
        bool IsKnownZone(string? timeZoneId);

        /// <summary>
        /// Interprets a naive wall-clock (the digits the organizer picked, zone ignored) as local to
        /// <paramref name="timeZoneId"/> and returns the corresponding UTC instant (<c>Kind=Utc</c>).
        /// The two awkward wall-clocks resolve leniently, matching the Flutter client: a spring-forward
        /// gap rolls forward to the next valid instant; an autumn fall-back takes the earlier occurrence.
        /// </summary>
        DateTime ConvertLocalToUtc(DateTime naiveLocal, string timeZoneId);

        /// <summary>
        /// Converts a UTC instant to the wall-clock in <paramref name="timeZoneId"/> (returned as
        /// <c>Kind=Unspecified</c>), for server-side display such as the reminder email.
        /// </summary>
        DateTime ConvertUtcToZone(DateTime utcInstant, string timeZoneId);
    }
}
