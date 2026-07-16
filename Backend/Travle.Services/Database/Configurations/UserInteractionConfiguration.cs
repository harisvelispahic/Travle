using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class UserInteractionConfiguration : BaseEntityConfiguration<UserInteraction>
    {
        public override void Configure(EntityTypeBuilder<UserInteraction> builder)
        {
            base.Configure(builder);

            builder.Property(i => i.SearchTerm).HasMaxLength(200);

            // Append-only diary: Restrict everywhere so a referenced entity cannot be deleted out from
            // under the recommender's history.
            builder.HasOne(i => i.User)
                .WithMany()
                .HasForeignKey(i => i.UserId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(i => i.Destination)
                .WithMany()
                .HasForeignKey(i => i.DestinationId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(i => i.Category)
                .WithMany()
                .HasForeignKey(i => i.CategoryId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasOne(i => i.Tag)
                .WithMany()
                .HasForeignKey(i => i.TagId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasIndex(i => new { i.UserId, i.CreatedAt });
        }
    }
}
