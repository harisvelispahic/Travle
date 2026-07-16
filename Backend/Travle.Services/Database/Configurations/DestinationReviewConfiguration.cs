using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class DestinationReviewConfiguration : BaseEntityConfiguration<DestinationReview>
    {
        public override void Configure(EntityTypeBuilder<DestinationReview> builder)
        {
            base.Configure(builder);

            builder.Property(r => r.Comment).HasMaxLength(1000);
            builder.Property(r => r.RemovalReason).HasMaxLength(500);

            builder.HasOne(r => r.Destination)
                .WithMany(d => d.Reviews)
                .HasForeignKey(r => r.DestinationId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.RemovedByUser)
                .WithMany()
                .HasForeignKey(r => r.RemovedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
