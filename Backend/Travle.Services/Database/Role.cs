namespace Travle.Services.Database
{
    /// <summary>
    /// Reference table of application roles (Admin, Traveler, Curator, Organizer). Seeded with fixed
    /// Ids and names; the names are load-bearing (they appear as JWT role claims and in authorization
    /// policies), so they are never renamed or deleted.
    /// </summary>
    public class Role : BaseEntity
    {
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
    }
}
