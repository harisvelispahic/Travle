using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddCityTimeZoneId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "TimeZoneId",
                table: "Cities",
                type: "nvarchar(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "Europe/Sarajevo");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "TimeZoneId",
                table: "Cities");
        }
    }
}
