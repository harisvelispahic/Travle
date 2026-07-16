namespace Travle.Services.Database
{
    /// <summary>
    /// A user's request for the Curator or Organizer role. Status-driven (never deleted) — the
    /// Pending → Approved/Rejected history with its audit fields is the value.
    /// </summary>
    public class RoleApplication : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int RoleId { get; set; }
        public Role Role { get; set; } = null!;

        public string Motivation { get; set; } = string.Empty;

        public int? RegionId { get; set; }
        public Region? Region { get; set; }

        public byte[]? Document { get; set; }
        public string? DocumentContentType { get; set; }

        public RoleApplicationStatus Status { get; set; } = RoleApplicationStatus.Pending;

        public int? DecidedByUserId { get; set; }
        public User? DecidedByUser { get; set; }

        public DateTime? DecidedAt { get; set; }
        public string? RejectionReason { get; set; }
    }
}
