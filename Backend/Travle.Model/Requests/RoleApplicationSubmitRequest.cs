namespace Travle.Model.Requests
{
    /// <summary>
    /// A request to apply for an elevated role. The applied-for role must be Curator or Organizer and
    /// the applicant must not already hold it — both enforced in the service (they depend on the DB).
    /// The supporting <see cref="Document"/> is optional (organizers attach documentation); when
    /// present its bytes are validated against the declared <see cref="DocumentContentType"/> by
    /// magic-byte sniffing, not by trusting the content type alone.
    /// </summary>
    public class RoleApplicationSubmitRequest
    {
        public int RoleId { get; set; }

        public string Motivation { get; set; } = string.Empty;

        /// <summary>Optional region the applicant wants to curate (relevant for Curator applications).</summary>
        public int? RegionId { get; set; }

        public byte[]? Document { get; set; }
        public string? DocumentContentType { get; set; }
    }
}
