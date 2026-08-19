namespace Travle.Model.Constants
{
    /// <summary>
    /// Time-zone defaults, in one place (no magic strings). Travle stores every timestamp as a UTC
    /// instant; <b>event</b> times (a tour schedule's start/end) are displayed in the zone of the tour's
    /// destination. That zone lives on <c>City.TimeZoneId</c> as an IANA identifier (e.g.
    /// <c>Europe/Sarajevo</c>). <see cref="PlatformTimeZoneId"/> is the fallback used when a city has no
    /// zone set and the platform-wide default the seeder assigns — Travle operates in Bosnia and
    /// Herzegovina, so every seeded city resolves here. Overridable per-deployment via
    /// <c>Time__PlatformTimeZoneId</c> (env <c>PLATFORM_TIMEZONE</c>). See docs/time-and-timezones.md.
    /// </summary>
    public static class TimeDefaults
    {
        public const string PlatformTimeZoneId = "Europe/Sarajevo";
    }
}
