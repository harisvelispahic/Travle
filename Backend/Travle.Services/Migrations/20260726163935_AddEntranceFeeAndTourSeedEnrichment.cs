using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddEntranceFeeAndTourSeedEnrichment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "EntranceFee",
                table: "Destinations",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 1,
                column: "EntranceFee",
                value: null);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 2,
                column: "EntranceFee",
                value: 10.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 3,
                column: "EntranceFee",
                value: 2.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 4,
                column: "EntranceFee",
                value: 5.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 5,
                column: "EntranceFee",
                value: null);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 6,
                column: "EntranceFee",
                value: null);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 7,
                column: "EntranceFee",
                value: 4.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 8,
                column: "EntranceFee",
                value: null);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 9,
                column: "EntranceFee",
                value: 6.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 10,
                column: "EntranceFee",
                value: 15.00m);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 11,
                column: "EntranceFee",
                value: null);

            migrationBuilder.UpdateData(
                table: "Destinations",
                keyColumn: "Id",
                keyValue: 12,
                column: "EntranceFee",
                value: null);

            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "CityId", "CreatedAt", "Email", "FirstName", "IsOnboarded", "IsSuspended", "LastName", "ModifiedAt", "OnboardingPromptCount", "PasswordHash", "PasswordSalt", "PhoneNumber", "ProfileImage", "ProfileImageContentType", "SuspendedAt", "SuspendedByUserId", "SuspensionReason", "Username" },
                values: new object[,]
                {
                    { 6, null, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "amir@travle.com", "Amir", false, false, "Hodžić", null, 0, "2FRMSidG5N9i/hqW9AXpRDLhOJq5DBQlRdE7MGBsaLU=", "d38hQJKnSdlVdlDAUMRJAA==", null, null, null, null, null, null, "amir_tours" },
                    { 7, null, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "selma@travle.com", "Selma", false, false, "Begić", null, 0, "2FRMSidG5N9i/hqW9AXpRDLhOJq5DBQlRdE7MGBsaLU=", "d38hQJKnSdlVdlDAUMRJAA==", null, null, null, null, null, null, "selma_travel" }
                });

            migrationBuilder.InsertData(
                table: "Tours",
                columns: new[] { "Id", "Capacity", "CreatedAt", "Description", "DurationMinutes", "IsActive", "ModifiedAt", "Name", "OrganizerId", "PricePerPerson", "TourTypeId" },
                values: new object[,]
                {
                    { 6, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A relaxed guided walk around the Jajce waterfall and the old town above it.", 90, true, null, "Jajce Waterfall Discovery", 6, 20.00m, 1 },
                    { 7, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A tasting walk through Baščaršija — ćevapi, Bosnian coffee and sweets among the coppersmiths.", 150, true, null, "Sarajevo Food & Bazaar Walk", 7, 35.00m, 4 },
                    { 8, 18, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A guided visit to the dramatic clifftop fortress of Srebrenik, one of Bosnia's best preserved.", 120, true, null, "Srebrenik Fortress Trail", 7, 22.00m, 2 },
                    { 9, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "An adventure day combining the Ostrožac castle with the canyons of the upper Una.", 300, true, null, "Una Canyon & Ostrožac Castle", 6, 55.00m, 3 },
                    { 10, 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "An unhurried heritage walk through Počitelj's stepped lanes and the Blagaj dervish lodge.", 240, true, null, "Počitelj & Blagaj Heritage Walk", 7, 38.00m, 2 }
                });

            migrationBuilder.InsertData(
                table: "UserRoles",
                columns: new[] { "RoleId", "UserId" },
                values: new object[,]
                {
                    { 4, 6 },
                    { 4, 7 }
                });

            migrationBuilder.InsertData(
                table: "TourDestinations",
                columns: new[] { "Id", "CreatedAt", "DestinationId", "ModifiedAt", "SortOrder", "TourId" },
                values: new object[,]
                {
                    { 11, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 9, null, 1, 6 },
                    { 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 11, null, 1, 7 },
                    { 13, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 6, null, 1, 8 },
                    { 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 4, null, 1, 9 },
                    { 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 10, null, 2, 9 },
                    { 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 8, null, 1, 10 },
                    { 17, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 7, null, 2, 10 }
                });

            migrationBuilder.InsertData(
                table: "TourSchedules",
                columns: new[] { "Id", "CancelledAt", "CancelledReason", "Capacity", "CreatedAt", "EndsAt", "ModifiedAt", "SeatsTaken", "StartsAt", "Status", "TourId" },
                values: new object[,]
                {
                    { 11, null, null, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 18, 11, 30, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 18, 10, 0, 0, 0, DateTimeKind.Utc), 0, 6 },
                    { 12, null, null, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 5, 11, 30, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 5, 10, 0, 0, 0, DateTimeKind.Utc), 0, 6 },
                    { 13, null, null, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 22, 19, 30, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 22, 17, 0, 0, 0, DateTimeKind.Utc), 0, 7 },
                    { 14, null, null, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 12, 19, 30, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 12, 17, 0, 0, 0, DateTimeKind.Utc), 0, 7 },
                    { 15, null, null, 18, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 28, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 28, 11, 0, 0, 0, DateTimeKind.Utc), 0, 8 },
                    { 16, null, null, 18, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 6, 15, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 6, 15, 11, 0, 0, 0, DateTimeKind.Utc), 0, 8 },
                    { 17, null, null, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 3, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 3, 8, 0, 0, 0, DateTimeKind.Utc), 0, 9 },
                    { 18, null, null, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 20, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 20, 8, 0, 0, 0, DateTimeKind.Utc), 0, 9 },
                    { 19, null, null, 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 30, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 30, 9, 0, 0, 0, DateTimeKind.Utc), 0, 10 },
                    { 20, null, null, 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 7, 5, 13, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 7, 5, 9, 0, 0, 0, DateTimeKind.Utc), 0, 10 }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 13);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 15);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "TourDestinations",
                keyColumn: "Id",
                keyValue: 17);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 11);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 12);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 13);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 14);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 15);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 16);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 17);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 18);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 19);

            migrationBuilder.DeleteData(
                table: "TourSchedules",
                keyColumn: "Id",
                keyValue: 20);

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumns: new[] { "RoleId", "UserId" },
                keyValues: new object[] { 4, 6 });

            migrationBuilder.DeleteData(
                table: "UserRoles",
                keyColumns: new[] { "RoleId", "UserId" },
                keyValues: new object[] { 4, 7 });

            migrationBuilder.DeleteData(
                table: "Tours",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Tours",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DeleteData(
                table: "Tours",
                keyColumn: "Id",
                keyValue: 8);

            migrationBuilder.DeleteData(
                table: "Tours",
                keyColumn: "Id",
                keyValue: 9);

            migrationBuilder.DeleteData(
                table: "Tours",
                keyColumn: "Id",
                keyValue: 10);

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: 6);

            migrationBuilder.DeleteData(
                table: "Users",
                keyColumn: "Id",
                keyValue: 7);

            migrationBuilder.DropColumn(
                name: "EntranceFee",
                table: "Destinations");
        }
    }
}
