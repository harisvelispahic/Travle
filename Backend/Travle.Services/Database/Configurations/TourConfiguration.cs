using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class TourConfiguration : BaseEntityConfiguration<Tour>
    {
        public override void Configure(EntityTypeBuilder<Tour> builder)
        {
            base.Configure(builder);

            builder.Property(t => t.Name)
                .IsRequired()
                .HasMaxLength(200);

            builder.Property(t => t.Description)
                .IsRequired()
                .HasMaxLength(4000);

            builder.Property(t => t.PricePerPerson).HasPrecision(18, 2);

            builder.HasOne(t => t.Organizer)
                .WithMany()
                .HasForeignKey(t => t.OrganizerId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(t => t.TourType)
                .WithMany(tt => tt.Tours)
                .HasForeignKey(t => t.TourTypeId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
