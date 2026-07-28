using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class Phase7SeedReviewableBooking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.InsertData(
                table: "Bookings",
                columns: new[] { "Id", "CancellationReason", "CancelledByUserId", "ConfirmedByUserId", "CreatedAt", "ExpiresAt", "ModifiedAt", "NumberOfPeople", "RejectionReason", "StatusChangedAt", "StatusId", "TotalAmount", "TourScheduleId", "UserId" },
                values: new object[] { 6, null, null, 2, new DateTime(2026, 6, 22, 10, 0, 0, 0, DateTimeKind.Utc), null, null, 1, null, new DateTime(2026, 6, 25, 14, 5, 0, 0, DateTimeKind.Utc), 4, 45.00m, 5, 4 });

            migrationBuilder.UpdateData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 5,
                column: "SeatsTaken",
                value: 1);

            migrationBuilder.InsertData(
                table: "Payments",
                columns: new[] { "Id", "Amount", "BookingId", "CreatedAt", "Currency", "ModifiedAt", "PlatformFeeAmount", "PlatformFeePercentage", "Status", "StripePaymentIntentId", "SucceededAt" },
                values: new object[] { 5, 45.00m, 6, new DateTime(2026, 6, 22, 10, 0, 0, 0, DateTimeKind.Utc), "bam", null, 4.50m, 10.00m, 1, "pi_seed_0005", new DateTime(2026, 6, 22, 10, 1, 0, 0, DateTimeKind.Utc) });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "Payments",
                keyColumn: "Id",
                keyValue: 5);

            migrationBuilder.DeleteData(
                table: "Bookings",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.UpdateData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 5,
                column: "SeatsTaken",
                value: 0);
        }
    }
}
