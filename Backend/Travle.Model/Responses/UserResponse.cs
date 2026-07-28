namespace Travle.Model.Responses
{
    /// <summary>
    /// Public user projection. Never carries the password hash/salt. <see cref="Roles"/> is a list
    /// because accounts can hold several roles at once. Read paths (list + self) carry only the small
    /// <see cref="ProfileImageThumbnail"/> (§8.2 — no heavy payloads); the full <see cref="ProfileImage"/>
    /// is populated only on the admin detail read and is null everywhere else.
    /// </summary>
    public class UserResponse
    {
        public int Id { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }

        public List<string> Roles { get; set; } = new List<string>();

        public bool IsSuspended { get; set; }
        public DateTime? SuspendedAt { get; set; }
        public string? SuspensionReason { get; set; }

        public int? CityId { get; set; }
        public string? CityName { get; set; }

        /// <summary>Whether the onboarding step should still be shown (drives the client's first-run routing).</summary>
        public bool IsOnboarded { get; set; }

        /// <summary>How many times onboarding has been shown to this user (feeds the re-prompt cap).</summary>
        public int OnboardingPromptCount { get; set; }

        public byte[]? ProfileImage { get; set; }
        public string? ProfileImageContentType { get; set; }

        /// <summary>Small JPEG avatar thumbnail; the image shipped on list + self reads (§8.2).</summary>
        public byte[]? ProfileImageThumbnail { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
