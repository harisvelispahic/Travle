using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class BookingStatusConfiguration : BaseEntityConfiguration<BookingStatus>
    {
        public override void Configure(EntityTypeBuilder<BookingStatus> builder)
        {
            base.Configure(builder);

            builder.Property(s => s.Name)
                .IsRequired()
                .HasMaxLength(50);

            builder.HasIndex(s => s.Name).IsUnique();
        }
    }
}
