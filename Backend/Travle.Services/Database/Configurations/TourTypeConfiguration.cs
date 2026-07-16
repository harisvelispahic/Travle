using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class TourTypeConfiguration : BaseEntityConfiguration<TourType>
    {
        public override void Configure(EntityTypeBuilder<TourType> builder)
        {
            base.Configure(builder);

            builder.Property(t => t.Name)
                .IsRequired()
                .HasMaxLength(100);

            builder.HasIndex(t => t.Name).IsUnique();
        }
    }
}
