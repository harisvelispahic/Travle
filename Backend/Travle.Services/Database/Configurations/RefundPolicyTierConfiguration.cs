using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class RefundPolicyTierConfiguration : BaseEntityConfiguration<RefundPolicyTier>
    {
        public override void Configure(EntityTypeBuilder<RefundPolicyTier> builder)
        {
            base.Configure(builder);

            builder.Property(t => t.HoursBeforeMin).IsRequired();
            builder.Property(t => t.Percentage).IsRequired();
        }
    }
}
