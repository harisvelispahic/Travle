namespace Travle.Model.Constants
{
    /// <summary>
    /// The four application role names, in one place (course §H: role names in a static class, no
    /// magic strings). These strings are the JWT role-claim values, the seeded <c>Role.Name</c>
    /// values, and the inputs to the authorization policies — they must stay in sync across all three.
    /// </summary>
    public static class RoleNames
    {
        public const string Admin = "Admin";
        public const string Traveler = "Traveler";
        public const string Curator = "Curator";
        public const string Organizer = "Organizer";
    }
}
