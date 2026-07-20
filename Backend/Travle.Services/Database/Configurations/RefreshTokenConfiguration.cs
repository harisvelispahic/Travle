using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class RefreshTokenConfiguration : BaseEntityConfiguration<RefreshToken>
    {
        public override void Configure(EntityTypeBuilder<RefreshToken> builder)
        {
            base.Configure(builder);

            // SHA-256 Base64Url ≈ 43 chars; 200 leaves headroom.
            builder.Property(rt => rt.TokenHash).IsRequired().HasMaxLength(200);

            // Refresh presents a token by hash — indexed for the lookup.
            builder.HasIndex(rt => rt.TokenHash);

            builder.HasOne(rt => rt.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(rt => rt.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
