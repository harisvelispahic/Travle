using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class DestinationImageConfiguration : BaseEntityConfiguration<DestinationImage>
    {
        public override void Configure(EntityTypeBuilder<DestinationImage> builder)
        {
            base.Configure(builder);

            builder.Property(i => i.ImageData).IsRequired();
            builder.Property(i => i.ThumbnailData).IsRequired();

            builder.Property(i => i.ContentType)
                .IsRequired()
                .HasMaxLength(100);

            builder.HasOne(i => i.Destination)
                .WithMany(d => d.Images)
                .HasForeignKey(i => i.DestinationId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
