using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class PaymentConfiguration : BaseEntityConfiguration<Payment>
    {
        public override void Configure(EntityTypeBuilder<Payment> builder)
        {
            base.Configure(builder);

            builder.Property(p => p.StripePaymentIntentId)
                .IsRequired()
                .HasMaxLength(255);

            builder.Property(p => p.Currency)
                .IsRequired()
                .HasMaxLength(3);

            builder.Property(p => p.Amount).HasPrecision(18, 2);
            builder.Property(p => p.PlatformFeeAmount).HasPrecision(18, 2);
            builder.Property(p => p.PlatformFeePercentage).HasPrecision(5, 2);

            builder.HasOne(p => p.Booking)
                .WithMany(b => b.Payments)
                .HasForeignKey(p => p.BookingId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasIndex(p => p.StripePaymentIntentId).IsUnique();
        }
    }
}
