using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingPaymentIdempotencyToken : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PaymentIdempotencyToken",
                table: "Bookings",
                type: "nvarchar(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            // Existing bookings land on the "" default, which the unique index below would reject (and which
            // would defeat the point of the column). Give each one its own token; NEWID() is evaluated per
            // row, and the formatting matches Guid.ToString("N") — 32 lowercase hex characters, no dashes.
            migrationBuilder.Sql(@"
                UPDATE [Bookings]
                SET [PaymentIdempotencyToken] = LOWER(REPLACE(CONVERT(nvarchar(36), NEWID()), '-', ''))
                WHERE [PaymentIdempotencyToken] = N'';");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_PaymentIdempotencyToken",
                table: "Bookings",
                column: "PaymentIdempotencyToken",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Bookings_PaymentIdempotencyToken",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "PaymentIdempotencyToken",
                table: "Bookings");
        }
    }
}
