using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddExpiredBookingSeed : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Bookings",
                columns: new[] { "Id", "CancellationReason", "CancelledByUserId", "ConfirmedByUserId", "CreatedAt", "ExpiresAt", "ModifiedAt", "NumberOfPeople", "RejectionReason", "StatusChangedAt", "StatusId", "TotalAmount", "TourScheduleId", "UserId" },
                values: new object[] { 5, null, null, null, new DateTime(2026, 7, 18, 14, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 7, 18, 14, 15, 0, 0, DateTimeKind.Utc), null, 2, null, new DateTime(2026, 7, 18, 14, 15, 0, 0, DateTimeKind.Utc), 6, 50.00m, 2, 5 });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Bookings",
                keyColumn: "Id",
                keyValue: 5);
        }
    }
}
