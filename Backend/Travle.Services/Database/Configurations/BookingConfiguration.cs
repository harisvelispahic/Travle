using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class BookingConfiguration : BaseEntityConfiguration<Booking>
    {
        public override void Configure(EntityTypeBuilder<Booking> builder)
        {
            base.Configure(builder);

            builder.Property(b => b.TotalAmount).HasPrecision(18, 2);
            builder.Property(b => b.RejectionReason).HasMaxLength(500);
            builder.Property(b => b.CancellationReason).HasMaxLength(500);

            builder.HasOne(b => b.User)
                .WithMany()
                .HasForeignKey(b => b.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(b => b.TourSchedule)
                .WithMany(s => s.Bookings)
                .HasForeignKey(b => b.TourScheduleId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(b => b.Status)
                .WithMany(s => s.Bookings)
                .HasForeignKey(b => b.StatusId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(b => b.ConfirmedByUser)
                .WithMany()
                .HasForeignKey(b => b.ConfirmedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(b => b.CancelledByUser)
                .WithMany()
                .HasForeignKey(b => b.CancelledByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            // Filtered unique index kills duplicate active bookings under races (03 §5).
            // StatusIds 1/2/3 = PaymentInProgress/Pending/Confirmed (seeded deterministically).
            builder.HasIndex(b => new { b.UserId, b.TourScheduleId })
                .IsUnique()
                .HasFilter("[StatusId] IN (1, 2, 3)");
        }
    }
}
