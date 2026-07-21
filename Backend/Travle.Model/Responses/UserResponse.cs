namespace Travle.Model.Responses
{
    /// <summary>
    /// Public user projection. Never carries the password hash/salt. <see cref="Roles"/> is a list
    /// because accounts can hold several roles at once. <see cref="ProfileImage"/> is populated on
    /// detail/self reads; list endpoints leave it null (§8.2 — no heavy payloads in lists).
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

        /// <summary>Whether the onboarding step has been completed or skipped (drives the client's first-run routing).</summary>
        public bool IsOnboarded { get; set; }

        public byte[]? ProfileImage { get; set; }
        public string? ProfileImageContentType { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
