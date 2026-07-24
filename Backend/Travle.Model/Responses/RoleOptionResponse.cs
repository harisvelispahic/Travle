namespace Travle.Model.Responses
{
    /// <summary>
    /// An elevated role a user may apply for (Curator or Organizer), as id + name. Backs the
    /// application picker so the client never hardcodes a role id — it resolves the target role by
    /// name from the applicable set returned for the current user.
    /// </summary>
    public class RoleOptionResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
    }
}
