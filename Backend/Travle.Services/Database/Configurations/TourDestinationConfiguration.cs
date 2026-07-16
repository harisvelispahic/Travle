using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class TourDestinationConfiguration : BaseEntityConfiguration<TourDestination>
    {
        public override void Configure(EntityTypeBuilder<TourDestination> builder)
        {
            base.Configure(builder);

            builder.HasOne(td => td.Tour)
                .WithMany(t => t.TourDestinations)
                .HasForeignKey(td => td.TourId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasOne(td => td.Destination)
                .WithMany(d => d.TourDestinations)
                .HasForeignKey(td => td.DestinationId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasIndex(td => new { td.TourId, td.DestinationId }).IsUnique();
        }
    }
}
