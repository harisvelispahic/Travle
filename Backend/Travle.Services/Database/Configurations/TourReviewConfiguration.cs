using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class TourReviewConfiguration : BaseEntityConfiguration<TourReview>
    {
        public override void Configure(EntityTypeBuilder<TourReview> builder)
        {
            base.Configure(builder);

            builder.Property(r => r.Comment).HasMaxLength(1000);
            builder.Property(r => r.RemovalReason).HasMaxLength(500);

            builder.HasOne(r => r.Tour)
                .WithMany(t => t.Reviews)
                .HasForeignKey(r => r.TourId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.Booking)
                .WithMany()
                .HasForeignKey(r => r.BookingId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.RemovedByUser)
                .WithMany()
                .HasForeignKey(r => r.RemovedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // One review per booking (stays occupied even after soft removal).
            builder.HasIndex(r => r.BookingId).IsUnique();
        }
    }
}
