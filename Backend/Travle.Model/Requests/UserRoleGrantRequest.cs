namespace Travle.Model.Requests
{
    /// <summary>
    /// Admin grant of a single role to an existing user (`POST /Users/{id}/Roles`). Revocation carries
    /// no body — the role is taken from the route (`DELETE /Users/{id}/Roles/{roleId}`).
    /// </summary>
    public class UserRoleGrantRequest
    {
        public int RoleId { get; set; }
    }
}
