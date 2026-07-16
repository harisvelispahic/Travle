using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class FavoriteConfiguration : BaseEntityConfiguration<Favorite>
    {
        public override void Configure(EntityTypeBuilder<Favorite> builder)
        {
            base.Configure(builder);

            builder.HasOne(f => f.User)
                .WithMany()
                .HasForeignKey(f => f.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasOne(f => f.Destination)
                .WithMany()
                .HasForeignKey(f => f.DestinationId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(f => f.Tour)
                .WithMany()
                .HasForeignKey(f => f.TourId)
                .OnDelete(DeleteBehavior.Restrict);

            // Exactly one target: a destination OR a tour, never both, never neither.
            builder.ToTable(t => t.HasCheckConstraint(
                "CK_Favorite_ExactlyOneTarget",
                "([DestinationId] IS NOT NULL AND [TourId] IS NULL) OR ([DestinationId] IS NULL AND [TourId] IS NOT NULL)"));

            // Unique per user+target (filtered so the null side does not collide).
            builder.HasIndex(f => new { f.UserId, f.DestinationId })
                .IsUnique()
                .HasFilter("[DestinationId] IS NOT NULL");

            builder.HasIndex(f => new { f.UserId, f.TourId })
                .IsUnique()
                .HasFilter("[TourId] IS NOT NULL");
        }
    }
}
