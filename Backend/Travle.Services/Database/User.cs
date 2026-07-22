namespace Travle.Services.Database
{
    /// <summary>
    /// An application account. A user may hold several roles at once (Traveler + Curator on one
    /// account is expected — see 03 §2), so role membership is the many-to-many
    /// <see cref="UserRoles"/>. Users are never hard-deleted; "removal" is suspension
    /// (<see cref="IsSuspended"/> + the audit fields), which also revokes their refresh tokens.
    /// </summary>
    public class User : BaseEntity
    {
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;

        public string PasswordHash { get; set; } = string.Empty;
        public string PasswordSalt { get; set; } = string.Empty;

        public string? PhoneNumber { get; set; }

        /// <summary>Full-size profile image bytes. Kept out of list DTOs (12/§8.2 — thumbnails only).</summary>
        public byte[]? ProfileImage { get; set; }

        /// <summary>Declared MIME type of <see cref="ProfileImage"/> (image/jpeg or image/png), verified against the bytes on upload.</summary>
        public string? ProfileImageContentType { get; set; }

        // Suspension = domain flag + audit (not on BaseEntity, per 02 §2b/§6a).
        public bool IsSuspended { get; set; }
        public DateTime? SuspendedAt { get; set; }
        public int? SuspendedByUserId { get; set; }
        public User? SuspendedByUser { get; set; }
        public string? SuspensionReason { get; set; }

        // Optional home city (recommender signal + profile detail).
        public int? CityId { get; set; }
        public City? City { get; set; }

        /// <summary>
        /// True once onboarding should no longer be shown — either the user submitted interests, or the
        /// prompt cap (<see cref="Travle.Services.Recommender.RecommenderOptions.MaxOnboardingPrompts"/>)
        /// was reached across launches. Drives the client's first-run routing.
        /// </summary>
        public bool IsOnboarded { get; set; }

        /// <summary>How many times the onboarding step has been shown to this user. Incremented once
        /// per display; when it reaches the configured cap, <see cref="IsOnboarded"/> is set so the
        /// step stops appearing even if the user never picks interests.</summary>
        public int OnboardingPromptCount { get; set; }

        public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
        public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    }
}
