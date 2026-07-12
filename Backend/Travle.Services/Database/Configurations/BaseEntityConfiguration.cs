using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Travle.Services.Database.Configurations
{
    /// <summary>
    /// Shared configuration for every <see cref="BaseEntity"/>: primary key and the audit
    /// timestamp columns. Concrete per-entity configurations inherit this, override
    /// <see cref="Configure"/>, call <c>base.Configure(builder)</c> first, then declare their own
    /// properties, relationships (explicit <c>HasOne/WithMany/HasForeignKey/OnDelete</c>) and indexes.
    /// Applied via <c>ApplyConfigurationsFromAssembly</c>. See docs/context/02 §4.
    /// </summary>
    public abstract class BaseEntityConfiguration<T> : IEntityTypeConfiguration<T>
        where T : BaseEntity
    {
        public virtual void Configure(EntityTypeBuilder<T> builder)
        {
            builder.HasKey(e => e.Id);

            builder.Property(e => e.CreatedAt)
                .IsRequired();

            builder.Property(e => e.ModifiedAt);
        }
    }
}
