namespace Travle.WebAPI.Authorization
{
    /// <summary>
    /// Authorization policy names (registered in Program.cs), referenced by endpoints instead of raw
    /// role strings — the full set is kept here for the whole picture even before every one is used.
    /// Because accounts are multi-role, <c>RequireRole</c> already matches a user who holds the role
    /// among several, and an "X or Y" endpoint is a single <c>RequireRole(x, y)</c> — so no
    /// combination policies are needed here (unlike Detailly's single-role model).
    /// </summary>
    public static class AuthPolicies
    {
        public const string Authenticated = "Authenticated";
        public const string AdminOnly = "AdminOnly";
        public const string OrganizerOnly = "OrganizerOnly";
        public const string CuratorOnly = "CuratorOnly";
        public const string TravelerOnly = "TravelerOnly";
    }
}
