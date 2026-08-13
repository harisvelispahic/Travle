using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <summary>
    /// Removes the compile-time <c>HasData</c> seed. All seed data — the reference tables, the demo users
    /// and every domain row — is now produced at runtime by <c>Travle.Services.Database.Seeding.BulkSeeder</c>
    /// (the sanctioned "rich data → runtime seeder" path, 02 §4), so the migrations describe schema only.
    /// This migration therefore clears the seeded rows and resets the <c>BookingStatuses</c> identity, so the
    /// runtime seeder re-creates the statuses on their contract ids (1-6). The deletes are ordered
    /// child → parent so foreign keys are never violated; on a fresh database this simply empties the rows the
    /// earlier migrations' <c>HasData</c> inserted, and on an existing database it wipes the old data so the
    /// runtime seeder can repopulate it cleanly.
    /// </summary>
    public partial class CentralizeSeed_RemoveHasData : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                DELETE FROM [UserInteractions];
                DELETE FROM [Notifications];
                DELETE FROM [RecommendationLogs];
                DELETE FROM [Favorites];
                DELETE FROM [TourReviews];
                DELETE FROM [DestinationReviews];
                DELETE FROM [Refunds];
                DELETE FROM [Payments];
                DELETE FROM [Bookings];
                DELETE FROM [TourSchedules];
                DELETE FROM [TourDestinations];
                DELETE FROM [DestinationImages];
                DELETE FROM [DestinationTags];
                DELETE FROM [RoleApplications];
                DELETE FROM [Destinations];
                DELETE FROM [Tours];
                DELETE FROM [PasswordResetCodes];
                DELETE FROM [RefreshTokens];
                DELETE FROM [UserRoles];
                DELETE FROM [Users];
                DELETE FROM [Cities];
                DELETE FROM [Regions];
                DELETE FROM [Countries];
                DELETE FROM [DestinationCategories];
                DELETE FROM [Tags];
                DELETE FROM [TourTypes];
                DELETE FROM [RefundPolicyTiers];
                DELETE FROM [BookingStatuses];
                DELETE FROM [Roles];
                DBCC CHECKIDENT('BookingStatuses', RESEED, 0);
                DBCC CHECKIDENT('Roles', RESEED, 0);
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Not reversible: the seed data is owned by the runtime BulkSeeder, not by migrations. Reverting
            // this migration cannot reconstruct the deleted rows.
            throw new NotSupportedException(
                "CentralizeSeed_RemoveHasData is not reversible — seed data is produced at runtime by BulkSeeder.");
        }
    }
}
