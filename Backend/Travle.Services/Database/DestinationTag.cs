namespace Travle.Services.Database
{
    /// <summary>
    /// Pure m2m link between <see cref="Destination"/> and <see cref="Tag"/>. Bare (no
    /// <see cref="BaseEntity"/>) — a composition row managed through the destination's edit form.
    /// Composite key (DestinationId, TagId); cascades away with its destination.
    /// </summary>
    public class DestinationTag
    {
        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        public int TagId { get; set; }
        public Tag Tag { get; set; } = null!;
    }
}
