using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class DestinationCategoryConfiguration : BaseEntityConfiguration<DestinationCategory>
    {
        public override void Configure(EntityTypeBuilder<DestinationCategory> builder)
        {
            base.Configure(builder);

            builder.Property(c => c.Name)
                .IsRequired()
                .HasMaxLength(100);

            builder.HasIndex(c => c.Name).IsUnique();
        }
    }
}
