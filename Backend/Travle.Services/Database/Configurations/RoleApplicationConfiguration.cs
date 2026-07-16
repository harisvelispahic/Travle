using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class RoleApplicationConfiguration : BaseEntityConfiguration<RoleApplication>
    {
        public override void Configure(EntityTypeBuilder<RoleApplication> builder)
        {
            base.Configure(builder);

            builder.Property(ra => ra.Motivation)
                .IsRequired()
                .HasMaxLength(1000);

            builder.Property(ra => ra.RejectionReason).HasMaxLength(500);
            builder.Property(ra => ra.DocumentContentType).HasMaxLength(100);

            builder.HasOne(ra => ra.User)
                .WithMany()
                .HasForeignKey(ra => ra.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(ra => ra.Role)
                .WithMany()
                .HasForeignKey(ra => ra.RoleId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(ra => ra.Region)
                .WithMany()
                .HasForeignKey(ra => ra.RegionId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(ra => ra.DecidedByUser)
                .WithMany()
                .HasForeignKey(ra => ra.DecidedByUserId)
                .OnDelete(DeleteBehavior.Restrict);
        }
    }
}
