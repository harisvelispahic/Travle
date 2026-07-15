using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Database
{
    public partial class TravleDbContext : DbContext
    {
        private void CreateConfiguration(ModelBuilder modelBuilder)
        {
            // UserRole join entity: cascade from both sides so removing a user or a role removes the
            // membership rows with it.
            modelBuilder.Entity<UserRole>()
                .HasOne(ur => ur.User)
                .WithMany(u => u.UserRoles)
                .HasForeignKey(ur => ur.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UserRole>()
                .HasOne(ur => ur.Role)
                .WithMany(r => r.UserRoles)
                .HasForeignKey(ur => ur.RoleId)
                .OnDelete(DeleteBehavior.Cascade);

            // Refresh tokens are owned by a user; deleting the user clears their tokens.
            modelBuilder.Entity<RefreshToken>()
                .HasOne(rt => rt.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(rt => rt.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
