using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Travle.Services.Database
{
    /// <summary>
    /// Design-time factory used ONLY by the EF Core tooling (<c>dotnet ef migrations add</c>,
    /// <c>database update</c>) so migrations can be scaffolded straight from this class library without
    /// booting the <c>Travle.WebAPI</c> host. It has <b>no effect at runtime</b> — the app builds its own
    /// <see cref="TravleDbContext"/> from DI in <c>Program.cs</c>. The connection string is read from the same
    /// env var the app uses, falling back to a local placeholder (scaffolding a migration never opens a
    /// connection, so any valid SQL Server string is enough to add/inspect migrations offline).
    /// </summary>
    public class DesignTimeTravleDbContextFactory : IDesignTimeDbContextFactory<TravleDbContext>
    {
        public TravleDbContext CreateDbContext(string[] args)
        {
            var connectionString =
                Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
                ?? Environment.GetEnvironmentVariable("CONNECTION_STRING")
                ?? "Server=localhost,1435;Database=230172;User Id=sa;Password=Placeholder_1;TrustServerCertificate=True";

            var options = new DbContextOptionsBuilder<TravleDbContext>()
                .UseSqlServer(connectionString)
                .Options;

            return new TravleDbContext(options);
        }
    }
}
