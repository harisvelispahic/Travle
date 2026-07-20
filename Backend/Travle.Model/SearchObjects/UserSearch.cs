namespace Travle.Model.SearchObjects
{
    public class UserSearch : BaseSearchObject
    {
        /// <summary>Filter by email (case-insensitive partial match).</summary>
        public string? Email { get; set; }

        /// <summary>Filter by username (case-insensitive partial match).</summary>
        public string? Username { get; set; }

        /// <summary>Filter by first or last name (case-insensitive partial match).</summary>
        public string? Name { get; set; }

        /// <summary>Filter by suspension state.</summary>
        public bool? IsSuspended { get; set; }

        /// <summary>Filter to users holding a given role (exact role name).</summary>
        public string? RoleName { get; set; }
    }
}
