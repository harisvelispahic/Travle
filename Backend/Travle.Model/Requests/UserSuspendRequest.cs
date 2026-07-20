namespace Travle.Model.Requests
{
    /// <summary>Admin-only suspension of a user, with a mandatory reason stored for the audit trail.</summary>
    public class UserSuspendRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
