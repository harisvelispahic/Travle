using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class RefundConfiguration : BaseEntityConfiguration<Refund>
    {
        public override void Configure(EntityTypeBuilder<Refund> builder)
        {
            base.Configure(builder);

            builder.Property(r => r.StripeRefundId).HasMaxLength(255);

            builder.Property(r => r.Reason)
                .IsRequired()
                .HasMaxLength(500);

            builder.Property(r => r.Amount).HasPrecision(18, 2);

            builder.HasOne(r => r.Payment)
                .WithMany(p => p.Refunds)
                .HasForeignKey(r => r.PaymentId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(r => r.InitiatedByUser)
                .WithMany()
                .HasForeignKey(r => r.InitiatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
