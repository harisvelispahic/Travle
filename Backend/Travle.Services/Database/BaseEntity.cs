namespace Travle.Services.Database
{
    /// <summary>
    /// Base type for all Travle entities. Provides the surrogate key and audit timestamps.
    /// <see cref="CreatedAt"/> / <see cref="ModifiedAt"/> are populated centrally in
    /// <c>TravleDbContext.SaveChanges</c> — never set them manually in a service.
    /// Soft-delete flags are intentionally NOT here: they are per-entity and named for their
    /// meaning (e.g. <c>IsRemoved</c>, <c>IsSuspended</c>). See docs/context/02 §2b/§6a.
    /// </summary>
    public abstract class BaseEntity
    {
        public int Id { get; set; }

        /// <summary>UTC timestamp of insertion.</summary>
        public DateTime CreatedAt { get; set; }

        /// <summary>UTC timestamp of the last update; null until first modified.</summary>
        public DateTime? ModifiedAt { get; set; }
    }
}
