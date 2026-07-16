using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class RecommendationLogConfiguration : BaseEntityConfiguration<RecommendationLog>
    {
        public override void Configure(EntityTypeBuilder<RecommendationLog> builder)
        {
            base.Configure(builder);

            builder.Property(l => l.Reason).HasMaxLength(500);

            builder.HasOne(l => l.User)
                .WithMany()
                .HasForeignKey(l => l.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(l => l.Destination)
                .WithMany()
                .HasForeignKey(l => l.DestinationId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
