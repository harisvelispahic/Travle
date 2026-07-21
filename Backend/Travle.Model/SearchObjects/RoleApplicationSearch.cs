namespace Travle.Model.SearchObjects
{
    public class RoleApplicationSearch : BaseSearchObject
    {
        /// <summary>
        /// Filter by decision status (drives the admin queue's Pending view). Matches the
        /// RoleApplicationStatus enum: 0 = Pending, 1 = Approved, 2 = Rejected. Kept as an int so the
        /// Model layer stays free of a dependency on the entity enum in Travle.Services.
        /// </summary>
        public int? Status { get; set; }

        /// <summary>Filter by the applied-for role.</summary>
        public int? RoleId { get; set; }

        /// <summary>Filter by applicant (used internally to scope a user to their own applications).</summary>
        public int? UserId { get; set; }
    }
}
