using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class TourScheduleConfiguration : BaseEntityConfiguration<TourSchedule>
    {
        public override void Configure(EntityTypeBuilder<TourSchedule> builder)
        {
            base.Configure(builder);

            builder.Property(s => s.CancelledReason).HasMaxLength(500);

            builder.HasOne(s => s.Tour)
                .WithMany(t => t.Schedules)
                .HasForeignKey(s => s.TourId)
                .OnDelete(DeleteBehavior.Cascade);

            builder.HasIndex(s => s.StartsAt);
        }
    }
}
