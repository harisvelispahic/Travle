using Travle.Model.Constants;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    public class CityConfiguration : BaseEntityConfiguration<City>
    {
        public override void Configure(EntityTypeBuilder<City> builder)
        {
            base.Configure(builder);

            builder.Property(c => c.Name)
                .IsRequired()
                .HasMaxLength(100);

            // IANA zone id (e.g. "Europe/Sarajevo"). Required; a DB default backfills existing rows on
            // migration and covers any insert that omits it. See docs/time-and-timezones.md.
            builder.Property(c => c.TimeZoneId)
                .IsRequired()
                .HasMaxLength(64)
                .HasDefaultValue(TimeDefaults.PlatformTimeZoneId);

            builder.HasOne(c => c.Region)
                .WithMany(r => r.Cities)
                .HasForeignKey(c => c.RegionId)
                .OnDelete(DeleteBehavior.Restrict);

            builder.HasIndex(c => new { c.RegionId, c.Name }).IsUnique();
        }
    }
}
