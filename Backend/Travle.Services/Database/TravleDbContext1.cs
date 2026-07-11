using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Database
{
    public partial class TravleDbContext : DbContext
    {
        public TravleDbContext(DbContextOptions<TravleDbContext> options) : base(options)
        {
        }

        // DbSets for all entities
        public DbSet<Category> Categories { get; set; }
        public DbSet<Product> Products { get; set; }
        public DbSet<ProductType> ProductTypes { get; set; }
        public DbSet<UnitOfMeasure> UnitOfMeasures { get; set; }
        public DbSet<ProductCategory> ProductCategories { get; set; }
        public DbSet<ProductReview> ProductReviews { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<Role> Roles { get; set; }
        public DbSet<UserRole> UserRoles { get; set; }
        public DbSet<Cart> Carts { get; set; }
        public DbSet<CartItem> CartItems { get; set; }
        public DbSet<Order> Orders { get; set; }
        public DbSet<OrderItem> OrderItems { get; set; }
        public DbSet<Asset> Assets { get; set; }
        public DbSet<RefreshToken> RefreshTokens { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            CreateConfiguration(modelBuilder);

            CreateSeed(modelBuilder);
            
        }

       
    }
}
