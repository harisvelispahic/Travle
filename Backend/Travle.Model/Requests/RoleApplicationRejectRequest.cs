namespace Travle.Model.Requests
{
    /// <summary>Admin rejection of a role application. The reason is mandatory (spec §2.4) and is
    /// surfaced back to the applicant in their notification and application history.</summary>
    public class RoleApplicationRejectRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
