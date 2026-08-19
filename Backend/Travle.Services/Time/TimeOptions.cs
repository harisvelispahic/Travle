using System.ComponentModel.DataAnnotations;
using Travle.Model.Constants;

namespace Travle.Services.Time
{
    /// <summary>
    /// Typed configuration for time-zone handling, bound once from the <c>Time</c> section (env
    /// <c>PLATFORM_TIMEZONE</c> via docker-compose, or the <c>Time__PlatformTimeZoneId</c> key in the
    /// repo-root <c>.env</c> for local runs). See docs/time-and-timezones.md.
    /// </summary>
    public sealed class TimeOptions
    {
        public const string SectionName = "Time";

        /// <summary>
        /// Platform-wide fallback IANA zone used when a city has no zone set and as the default the seeder
        /// assigns. Must be a valid IANA identifier. Defaults to
        /// <see cref="TimeDefaults.PlatformTimeZoneId"/> (Europe/Sarajevo).
        /// </summary>
        [Required]
        public string PlatformTimeZoneId { get; set; } = TimeDefaults.PlatformTimeZoneId;
    }
}
