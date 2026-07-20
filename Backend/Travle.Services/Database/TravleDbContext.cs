using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Database
{
    public partial class TravleDbContext : DbContext
    {
        public TravleDbContext(DbContextOptions<TravleDbContext> options) : base(options)
        {
        }

        // Auth / identity
        public DbSet<User> Users { get; set; }
        public DbSet<Role> Roles { get; set; }
        public DbSet<UserRole> UserRoles { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }

        // Reference data
        public DbSet<Country> Countries { get; set; }
        public DbSet<Region> Regions { get; set; }
        public DbSet<City> Cities { get; set; }
        public DbSet<DestinationCategory> DestinationCategories { get; set; }
        public DbSet<TourType> TourTypes { get; set; }
        public DbSet<Tag> Tags { get; set; }
        public DbSet<DestinationTag> DestinationTags { get; set; }
        public DbSet<TourDestination> TourDestinations { get; set; }
        public DbSet<BookingStatus> BookingStatuses { get; set; }
        public DbSet<RefundPolicyTier> RefundPolicyTiers { get; set; }

        // Main domain
        public DbSet<RoleApplication> RoleApplications { get; set; }
        public DbSet<Destination> Destinations { get; set; }
        public DbSet<DestinationImage> DestinationImages { get; set; }
        public DbSet<Tour> Tours { get; set; }
        public DbSet<TourSchedule> TourSchedules { get; set; }
        public DbSet<Booking> Bookings { get; set; }
        public DbSet<Payment> Payments { get; set; }
        public DbSet<Refund> Refunds { get; set; }
        public DbSet<DestinationReview> DestinationReviews { get; set; }
        public DbSet<TourReview> TourReviews { get; set; }
        public DbSet<Favorite> Favorites { get; set; }
        public DbSet<Notification> Notifications { get; set; }
        public DbSet<UserInteraction> UserInteractions { get; set; }
        public DbSet<PasswordResetCode> PasswordResetCodes { get; set; }
        public DbSet<RecommendationLog> RecommendationLogs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Per-entity IEntityTypeConfiguration<T> classes in Database/Configurations (auth entities
            // included — User/Role/UserRole/RefreshToken now have their own configuration classes).
            modelBuilder.ApplyConfigurationsFromAssembly(typeof(TravleDbContext).Assembly);

            CreateSeed(modelBuilder);
        }

        public override int SaveChanges(bool acceptAllChangesOnSuccess)
        {
            ApplyAuditTimestamps();
            return base.SaveChanges(acceptAllChangesOnSuccess);
        }

        public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
        {
            ApplyAuditTimestamps();
            return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }

        /// <summary>
        /// Single source of truth for audit timestamps: stamps <see cref="BaseEntity.CreatedAt"/> on
        /// insert and <see cref="BaseEntity.ModifiedAt"/> on update, in UTC, for every tracked
        /// <see cref="BaseEntity"/>. Services must never set these by hand. Runs on every save path
        /// (sync and async) because both public overloads funnel through these two overrides.
        /// </summary>
        private void ApplyAuditTimestamps()
        {
            var now = DateTime.UtcNow;

            foreach (var entry in ChangeTracker.Entries<BaseEntity>())
            {
                switch (entry.State)
                {
                    case EntityState.Added:
                        entry.Entity.CreatedAt = now;
                        break;
                    case EntityState.Modified:
                        entry.Entity.ModifiedAt = now;
                        break;
                }
            }
        }
    }
}
