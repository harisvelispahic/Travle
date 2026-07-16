using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    /// <summary>
    /// Bare m2m link (no <see cref="BaseEntity"/>) — does not inherit <see cref="BaseEntityConfiguration{T}"/>.
    /// Composite key; cascades from the destination, restricted from the tag so a tag in use cannot be deleted.
    /// </summary>
    public class DestinationTagConfiguration : IEntityTypeConfiguration<DestinationTag>
    {
        public void Configure(EntityTypeBuilder<DestinationTag> builder)
        {
            builder.HasKey(dt => new { dt.DestinationId, dt.TagId });

            builder.HasOne(dt => dt.Destination)
                .WithMany(d => d.DestinationTags)
                .HasForeignKey(dt => dt.DestinationId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasOne(dt => dt.Tag)
                .WithMany(t => t.DestinationTags)
                .HasForeignKey(dt => dt.TagId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
