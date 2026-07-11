namespace Travle.Model.SearchObjects
{
    public class UserSearch : BaseSearchObject
    {
        /// <summary>
        /// Search for users by email (case-insensitive partial match).
        /// </summary>
        public string? Email { get; set; }

        /// <summary>
        /// Search for users by username (case-insensitive partial match).
        /// </summary>
        public string? Username { get; set; }

        /// <summary>
        /// Search for users by first or last name (case-insensitive partial match).
        /// </summary>
        public string? Name { get; set; }

        /// <summary>
        /// Filter by active/inactive users.
        /// </summary>
        public bool? IsActive { get; set; }
    }
}
