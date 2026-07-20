namespace Travle.WebAPI.Authorization
{
    /// <summary>
    /// Authorization policy names (registered in Program.cs), referenced by endpoints instead of raw
    /// role strings. Only the policies actually in use live here; add role policies
    /// (e.g. OrganizerOnly, CuratorOnly) when the endpoints that need them arrive. Because accounts
    /// are multi-role, <c>RequireRole</c> already matches a user who holds the role among several —
    /// and an "X or Y" endpoint is a single <c>RequireRole(x, y)</c>, so no combination policies are
    /// needed here (unlike Detailly's single-role model).
    /// </summary>
    public static class AuthPolicies
    {
        public const string Authenticated = "Authenticated";
        public const string AdminOnly = "AdminOnly";
    }
}
