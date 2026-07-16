using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class DestinationConfiguration : BaseEntityConfiguration<Destination>
    {
        public override void Configure(EntityTypeBuilder<Destination> builder)
        {
            base.Configure(builder);

            builder.Property(d => d.Name)
                .IsRequired()
                .HasMaxLength(200);

            builder.Property(d => d.Description)
                .IsRequired()
                .HasMaxLength(4000);

            builder.Property(d => d.RejectionReason).HasMaxLength(500);

            builder.HasOne(d => d.Category)
                .WithMany(c => c.Destinations)
                .HasForeignKey(d => d.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(d => d.City)
                .WithMany(c => c.Destinations)
                .HasForeignKey(d => d.CityId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(d => d.SubmittedByUser)
                .WithMany()
                .HasForeignKey(d => d.SubmittedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(d => d.ModeratedByUser)
                .WithMany()
                .HasForeignKey(d => d.ModeratedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasIndex(d => d.Name);
            builder.HasIndex(d => new { d.CategoryId, d.Status });
        }
    }
}
