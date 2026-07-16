using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class PasswordResetCodeConfiguration : BaseEntityConfiguration<PasswordResetCode>
    {
        public override void Configure(EntityTypeBuilder<PasswordResetCode> builder)
        {
            base.Configure(builder);

            builder.Property(c => c.CodeHash)
                .IsRequired()
                .HasMaxLength(500);

            builder.HasOne(c => c.User)
                .WithMany()
                .HasForeignKey(c => c.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
