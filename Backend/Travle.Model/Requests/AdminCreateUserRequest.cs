namespace Travle.Model.Requests
{
    /// <summary>
    /// Admin-only account creation (`POST /Users`). Unlike self-registration (`/Access/Register`, always
    /// Traveler), the admin sets the initial password and assigns any combination of the four roles —
    /// including Admin, which has no other grant path. Never reachable anonymously; the service re-checks
    /// the Admin role.
    /// </summary>
    public class AdminCreateUserRequest
    {
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }

        /// <summary>The roles to grant the new account, by <c>Role.Id</c>. At least one; each must exist.</summary>
        public List<int> RoleIds { get; set; } = new List<int>();
    }
}
