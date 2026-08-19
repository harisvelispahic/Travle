using Microsoft.Extensions.Options;
using NodaTime;

namespace Travle.Services.Time
{
    /// <inheritdoc cref="ITimeZoneService"/>
    public sealed class TimeZoneService : ITimeZoneService
    {
        // NodaTime's bundled IANA (tzdb) database — no dependency on the host OS's zoneinfo files, so the
        // conversion is identical on the developer's Windows machine and in the Linux API container.
        private static readonly IDateTimeZoneProvider Tzdb = DateTimeZoneProviders.Tzdb;

        public string PlatformTimeZoneId { get; }

        public TimeZoneService(IOptions<TimeOptions> options)
        {
            var configured = options.Value.PlatformTimeZoneId;
            // Fail fast on a misconfigured deployment rather than silently mis-displaying every event time.
            PlatformTimeZoneId = Tzdb.GetZoneOrNull(configured) is not null
                ? configured
                : throw new InvalidOperationException(
                    $"Configured platform time zone '{configured}' is not a valid IANA identifier.");
        }

        public bool IsKnownZone(string? timeZoneId)
            => !string.IsNullOrWhiteSpace(timeZoneId) && Tzdb.GetZoneOrNull(timeZoneId) is not null;

        public DateTime ConvertLocalToUtc(DateTime naiveLocal, string timeZoneId)
        {
            var zone = GetZoneOrPlatform(timeZoneId);
            var local = LocalDateTime.FromDateTime(DateTime.SpecifyKind(naiveLocal, DateTimeKind.Unspecified));

            // Lenient resolution of the two awkward wall-clocks so the whole system behaves the same way:
            //   • spring-forward gap  → roll forward to the next valid instant;
            //   • autumn fall-back    → take the earlier (first) occurrence.
            // This mirrors the Flutter client, whose DateTime(...) constructor already normalises a
            // non-existent local time forward before it is ever sent, so a same-zone organizer never even
            // reaches a gap here. See docs/time-and-timezones.md §3.
            return local.InZoneLeniently(zone).ToDateTimeUtc();
        }

        public DateTime ConvertUtcToZone(DateTime utcInstant, string timeZoneId)
        {
            var zone = GetZoneOrPlatform(timeZoneId);
            var instant = Instant.FromDateTimeUtc(DateTime.SpecifyKind(utcInstant, DateTimeKind.Utc));
            return instant.InZone(zone).ToDateTimeUnspecified();
        }

        // The platform zone is validated in the constructor, so this never returns null.
        private DateTimeZone GetZoneOrPlatform(string? timeZoneId)
            => (Tzdb.GetZoneOrNull(timeZoneId ?? string.Empty) ?? Tzdb.GetZoneOrNull(PlatformTimeZoneId))!;
    }
}
