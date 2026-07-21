namespace Travle.Model.Responses
{
    /// <summary>
    /// A user's request for the Curator or Organizer role, with its full decision history. The
    /// supporting <c>Document</c> bytes are never carried here (§8.2 — no heavy payloads in lists);
    /// <see cref="HasDocument"/> tells the client whether to offer the dedicated download endpoint.
    /// </summary>
    public class RoleApplicationResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        /// <summary>Flattened from User.Username so the moderation queue never shows a raw id.</summary>
        public string? Username { get; set; }
        /// <summary>Flattened "FirstName LastName" of the applicant.</summary>
        public string? ApplicantName { get; set; }

        public int RoleId { get; set; }
        /// <summary>The applied-for role name (Curator or Organizer), flattened from Role.Name.</summary>
        public string? RoleName { get; set; }

        public string Motivation { get; set; } = string.Empty;

        public int? RegionId { get; set; }
        public string? RegionName { get; set; }

        /// <summary>Whether a supporting document is attached (fetch it via the document endpoint).</summary>
        public bool HasDocument { get; set; }
        public string? DocumentContentType { get; set; }

        /// <summary>Pending / Approved / Rejected — the enum name, never the raw int.</summary>
        public string Status { get; set; } = string.Empty;

        public int? DecidedByUserId { get; set; }
        public string? DecidedByUsername { get; set; }
        public DateTime? DecidedAt { get; set; }
        public string? RejectionReason { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
