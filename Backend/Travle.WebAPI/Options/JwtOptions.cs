using System.ComponentModel.DataAnnotations;

namespace Travle.WebAPI.Options
{
    /// <summary>
    /// Typed JWT settings, bound once from the <c>JwtToken</c> configuration section (fed by the
    /// <c>JWT_*</c> environment variables via docker-compose). Validated on startup so a missing or
    /// too-short signing key fails fast rather than at first login.
    /// </summary>
    public sealed class JwtOptions
    {
        public const string SectionName = "JwtToken";

        [Required, MinLength(32)]
        public string SecretKey { get; set; } = default!;

        [Required]
        public string Issuer { get; set; } = default!;

        [Required]
        public string Audience { get; set; } = default!;

        [Range(1, 1440)]
        public int DurationInMinutes { get; set; } = 30;

        [Range(1, 90)]
        public int RefreshTokenDays { get; set; } = 7;
    }
}
