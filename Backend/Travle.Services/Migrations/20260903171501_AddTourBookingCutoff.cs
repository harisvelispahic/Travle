using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddTourBookingCutoff : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BookingCutoffMinutes",
                table: "Tours",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BookingCutoffMinutes",
                table: "Tours");
        }
    }
}
