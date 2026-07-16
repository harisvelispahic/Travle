using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "BookingStatuses",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BookingStatuses", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Countries",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Countries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "DestinationCategories",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DestinationCategories", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "RefundPolicyTiers",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    HoursBeforeMin = table.Column<int>(type: "int", nullable: false),
                    HoursBeforeMax = table.Column<int>(type: "int", nullable: true),
                    Percentage = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefundPolicyTiers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Roles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Roles", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Tags",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tags", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TourTypes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TourTypes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    FirstName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    LastName = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Username = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    PasswordSalt = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    LastLoginAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    PhoneNumber = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    ProfileImageBase64 = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Regions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    CountryId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Regions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Regions_Countries_CountryId",
                        column: x => x.CountryId,
                        principalTable: "Countries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Notifications",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Text = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    IsRead = table.Column<bool>(type: "bit", nullable: false),
                    ReadAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RelatedEntityId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Notifications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Notifications_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PasswordResetCodes",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    CodeHash = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PasswordResetCodes", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PasswordResetCodes_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RefreshTokens",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Token = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RefreshTokens", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RefreshTokens_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Tours",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    OrganizerId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    DurationMinutes = table.Column<int>(type: "int", nullable: false),
                    PricePerPerson = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Capacity = table.Column<int>(type: "int", nullable: false),
                    TourTypeId = table.Column<int>(type: "int", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tours", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Tours_TourTypes_TourTypeId",
                        column: x => x.TourTypeId,
                        principalTable: "TourTypes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Tours_Users_OrganizerId",
                        column: x => x.OrganizerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserRoles",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    RoleId = table.Column<int>(type: "int", nullable: false),
                    DateAssigned = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserRoles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserRoles_Roles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "Roles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserRoles_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Cities",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    RegionId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cities", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Cities_Regions_RegionId",
                        column: x => x.RegionId,
                        principalTable: "Regions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RoleApplications",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    RoleId = table.Column<int>(type: "int", nullable: false),
                    Motivation = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    RegionId = table.Column<int>(type: "int", nullable: true),
                    Document = table.Column<byte[]>(type: "varbinary(max)", nullable: true),
                    DocumentContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Status = table.Column<int>(type: "int", nullable: false),
                    DecidedByUserId = table.Column<int>(type: "int", nullable: true),
                    DecidedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RoleApplications", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RoleApplications_Regions_RegionId",
                        column: x => x.RegionId,
                        principalTable: "Regions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoleApplications_Roles_RoleId",
                        column: x => x.RoleId,
                        principalTable: "Roles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoleApplications_Users_DecidedByUserId",
                        column: x => x.DecidedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RoleApplications_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TourSchedules",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TourId = table.Column<int>(type: "int", nullable: false),
                    StartsAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndsAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Capacity = table.Column<int>(type: "int", nullable: false),
                    SeatsTaken = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    CancelledReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CancelledAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TourSchedules", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TourSchedules_Tours_TourId",
                        column: x => x.TourId,
                        principalTable: "Tours",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Destinations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: false),
                    CategoryId = table.Column<int>(type: "int", nullable: false),
                    CityId = table.Column<int>(type: "int", nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    SubmittedByUserId = table.Column<int>(type: "int", nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    ModeratedByUserId = table.Column<int>(type: "int", nullable: true),
                    ModeratedAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    IsFeatured = table.Column<bool>(type: "bit", nullable: false),
                    AverageRating = table.Column<double>(type: "float", nullable: false),
                    ViewCount = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Destinations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Destinations_Cities_CityId",
                        column: x => x.CityId,
                        principalTable: "Cities",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Destinations_DestinationCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "DestinationCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Destinations_Users_ModeratedByUserId",
                        column: x => x.ModeratedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Destinations_Users_SubmittedByUserId",
                        column: x => x.SubmittedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Bookings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    TourScheduleId = table.Column<int>(type: "int", nullable: false),
                    NumberOfPeople = table.Column<int>(type: "int", nullable: false),
                    TotalAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    StatusId = table.Column<int>(type: "int", nullable: false),
                    StatusChangedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ConfirmedByUserId = table.Column<int>(type: "int", nullable: true),
                    RejectionReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CancelledByUserId = table.Column<int>(type: "int", nullable: true),
                    CancellationReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ExpiresAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bookings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Bookings_BookingStatuses_StatusId",
                        column: x => x.StatusId,
                        principalTable: "BookingStatuses",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Bookings_TourSchedules_TourScheduleId",
                        column: x => x.TourScheduleId,
                        principalTable: "TourSchedules",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Bookings_Users_CancelledByUserId",
                        column: x => x.CancelledByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Bookings_Users_ConfirmedByUserId",
                        column: x => x.ConfirmedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Bookings_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DestinationImages",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DestinationId = table.Column<int>(type: "int", nullable: false),
                    ImageData = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                    ThumbnailData = table.Column<byte[]>(type: "varbinary(max)", nullable: false),
                    ContentType = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DestinationImages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DestinationImages_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "DestinationReviews",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DestinationId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    Rating = table.Column<int>(type: "int", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    IsRemoved = table.Column<bool>(type: "bit", nullable: false),
                    RemovedByUserId = table.Column<int>(type: "int", nullable: true),
                    RemovalReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DestinationReviews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DestinationReviews_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DestinationReviews_Users_RemovedByUserId",
                        column: x => x.RemovedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DestinationReviews_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "DestinationTags",
                columns: table => new
                {
                    DestinationId = table.Column<int>(type: "int", nullable: false),
                    TagId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DestinationTags", x => new { x.DestinationId, x.TagId });
                    table.ForeignKey(
                        name: "FK_DestinationTags_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_DestinationTags_Tags_TagId",
                        column: x => x.TagId,
                        principalTable: "Tags",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Favorites",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    DestinationId = table.Column<int>(type: "int", nullable: true),
                    TourId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Favorites", x => x.Id);
                    table.CheckConstraint("CK_Favorite_ExactlyOneTarget", "([DestinationId] IS NOT NULL AND [TourId] IS NULL) OR ([DestinationId] IS NULL AND [TourId] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_Favorites_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Favorites_Tours_TourId",
                        column: x => x.TourId,
                        principalTable: "Tours",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Favorites_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    DestinationId = table.Column<int>(type: "int", nullable: false),
                    Score = table.Column<double>(type: "float", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ServedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationLogs_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_RecommendationLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TourDestinations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TourId = table.Column<int>(type: "int", nullable: false),
                    DestinationId = table.Column<int>(type: "int", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TourDestinations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TourDestinations_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TourDestinations_Tours_TourId",
                        column: x => x.TourId,
                        principalTable: "Tours",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserInteractions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    DestinationId = table.Column<int>(type: "int", nullable: true),
                    InteractionType = table.Column<int>(type: "int", nullable: false),
                    Weight = table.Column<double>(type: "float", nullable: false),
                    SearchTerm = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true),
                    CategoryId = table.Column<int>(type: "int", nullable: true),
                    TagId = table.Column<int>(type: "int", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserInteractions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserInteractions_DestinationCategories_CategoryId",
                        column: x => x.CategoryId,
                        principalTable: "DestinationCategories",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserInteractions_Destinations_DestinationId",
                        column: x => x.DestinationId,
                        principalTable: "Destinations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserInteractions_Tags_TagId",
                        column: x => x.TagId,
                        principalTable: "Tags",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserInteractions_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Payments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    BookingId = table.Column<int>(type: "int", nullable: false),
                    StripePaymentIntentId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    PlatformFeePercentage = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false),
                    PlatformFeeAmount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    Status = table.Column<int>(type: "int", nullable: false),
                    SucceededAt = table.Column<DateTime>(type: "datetime2", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Payments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Payments_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TourReviews",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TourId = table.Column<int>(type: "int", nullable: false),
                    BookingId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    Rating = table.Column<int>(type: "int", nullable: false),
                    Comment = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    IsRemoved = table.Column<bool>(type: "bit", nullable: false),
                    RemovedByUserId = table.Column<int>(type: "int", nullable: true),
                    RemovalReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TourReviews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TourReviews_Bookings_BookingId",
                        column: x => x.BookingId,
                        principalTable: "Bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TourReviews_Tours_TourId",
                        column: x => x.TourId,
                        principalTable: "Tours",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TourReviews_Users_RemovedByUserId",
                        column: x => x.RemovedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TourReviews_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Refunds",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PaymentId = table.Column<int>(type: "int", nullable: false),
                    StripeRefundId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    Amount = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    PercentageApplied = table.Column<int>(type: "int", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    InitiatedByUserId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ModifiedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Refunds", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Refunds_Payments_PaymentId",
                        column: x => x.PaymentId,
                        principalTable: "Payments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Refunds_Users_InitiatedByUserId",
                        column: x => x.InitiatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "BookingStatuses",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "PaymentInProgress" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Pending" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Confirmed" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Completed" },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Cancelled" },
                    { 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Expired" }
                });

            migrationBuilder.InsertData(
                table: "Countries",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Bosnia and Herzegovina" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Croatia" }
                });

            migrationBuilder.InsertData(
                table: "DestinationCategories",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Historical Site" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Natural Wonder" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Religious Site" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Cultural Landmark" },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Adventure" },
                    { 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Museum" },
                    { 7, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Old Town" }
                });

            migrationBuilder.InsertData(
                table: "RefundPolicyTiers",
                columns: new[] { "Id", "CreatedAt", "HoursBeforeMax", "HoursBeforeMin", "ModifiedAt", "Percentage" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, 72, null, 100 },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 72, 24, null, 50 },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 24, 1, null, 25 },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, 0, null, 0 }
                });

            migrationBuilder.InsertData(
                table: "Roles",
                columns: new[] { "Id", "CreatedAt", "Description", "IsActive", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Administrator role with full permissions", true, "Admin" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Default customer role", true, "Customer" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Submits and curates tourist destinations", true, "Curator" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Creates and manages tours and schedules", true, "Organizer" }
                });

            migrationBuilder.InsertData(
                table: "Tags",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "UNESCO" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Waterfall" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Ottoman" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Medieval" },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Hiking" },
                    { 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Photography" },
                    { 7, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Family Friendly" },
                    { 8, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "River" },
                    { 9, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Bridge" },
                    { 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Fortress" },
                    { 11, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Nature" },
                    { 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Swimming" },
                    { 13, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Pilgrimage" },
                    { 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Old Town" },
                    { 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Mountains" },
                    { 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Museum" },
                    { 17, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Architecture" }
                });

            migrationBuilder.InsertData(
                table: "TourTypes",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Walking Tour" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Cultural Tour" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Adventure Tour" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Food Tour" },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Private Tour" }
                });

            migrationBuilder.InsertData(
                table: "Users",
                columns: new[] { "Id", "CreatedAt", "Email", "FirstName", "IsActive", "LastLoginAt", "LastName", "PasswordHash", "PasswordSalt", "PhoneNumber", "ProfileImageBase64", "Username" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "admin1@gmail.com", "Alice", true, null, "Admin", "5kRBQg4Ufcx4hAknG7P9zhfLPvY=", "FmvmUwPsJyRRffhNRQvbrA==", null, null, "admin1" },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "admin2@gmail.com", "Bob", true, null, "Admin", "GBoyh1WP+OMgGjqRj6vK6L1+oGc=", "0AXpKx6xRp9xM42jCf/PiA==", null, null, "admin2" },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "admin3@gmail.com", "Carol", true, null, "Admin", "x6JHKCTQywdAzTcZxGWFvrKPORM=", "IwhTfKQNgyqWfOlTqCDXrg==", null, null, "admin3" },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "customer1@gmail.com", "Dave", true, null, "Customer", "E0fA2/f9GZvIRRt/cgqQemG/Cog=", "TiJxWTJcd7sBSiWNbhK9Vw==", null, null, "customer1" },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "customer2@gmail.com", "Eve", true, null, "Customer", "Ov4LxpWKXXV9dwMYvBgqODdzIt0=", "KtWF6g7SemBqs4nVWV4Ziw==", null, null, "customer2" }
                });

            migrationBuilder.InsertData(
                table: "Notifications",
                columns: new[] { "Id", "CreatedAt", "IsRead", "ModifiedAt", "ReadAt", "RelatedEntityId", "Text", "Title", "Type", "UserId" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 6, 15, 9, 5, 0, 0, DateTimeKind.Utc), true, null, new DateTime(2026, 6, 16, 8, 0, 0, 0, DateTimeKind.Utc), 1, "Your booking for 'Mostar Old Town Walking Tour' has been confirmed.", "Booking confirmed", 1, 5 },
                    { 2, new DateTime(2026, 6, 20, 13, 0, 0, 0, DateTimeKind.Utc), false, null, null, 1, "Your tour is completed. Share your experience by leaving a review!", "Tour completed", 6, 5 },
                    { 3, new DateTime(2026, 7, 10, 11, 5, 0, 0, DateTimeKind.Utc), false, null, null, 2, "Your booking for 'Sarajevo Cultural Heritage Tour' has been confirmed.", "Booking confirmed", 1, 4 },
                    { 4, new DateTime(2026, 7, 5, 10, 5, 0, 0, DateTimeKind.Utc), false, null, null, 3, "A refund of 120.00 KM has been issued for your cancelled booking.", "Refund issued", 8, 5 }
                });

            migrationBuilder.InsertData(
                table: "Regions",
                columns: new[] { "Id", "CountryId", "CreatedAt", "ModifiedAt", "Name" },
                values: new object[,]
                {
                    { 1, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Sarajevo Canton" },
                    { 2, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Herzegovina-Neretva" },
                    { 3, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Una-Sana" },
                    { 4, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Central Bosnia" },
                    { 5, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Tuzla" },
                    { 6, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Zenica-Doboj" },
                    { 7, 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Dubrovnik-Neretva" }
                });

            migrationBuilder.InsertData(
                table: "Tours",
                columns: new[] { "Id", "Capacity", "CreatedAt", "Description", "DurationMinutes", "IsActive", "ModifiedAt", "Name", "OrganizerId", "PricePerPerson", "TourTypeId" },
                values: new object[,]
                {
                    { 1, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A guided walk across Stari Most and through the old bazaar, ending at Blagaj Tekija.", 120, true, null, "Mostar Old Town Walking Tour", 4, 25.00m, 1 },
                    { 2, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A full-day excursion to the Kravice waterfalls with a stop in Počitelj.", 300, true, null, "Kravice Waterfalls Day Trip", 4, 45.00m, 3 },
                    { 3, 20, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "From Vrelo Bosne to Baščaršija — the natural and Ottoman heritage around Sarajevo.", 180, true, null, "Sarajevo Cultural Heritage Tour", 5, 30.00m, 2 },
                    { 4, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A guided rafting descent of the upper Una with a visit to Bihać old town.", 240, true, null, "Una National Park Rafting", 5, 60.00m, 3 },
                    { 5, 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A half-day cultural excursion to the Buna spring and the fortress village of Počitelj.", 360, true, null, "Blagaj & Počitelj Excursion", 4, 40.00m, 2 }
                });

            migrationBuilder.InsertData(
                table: "UserInteractions",
                columns: new[] { "Id", "CategoryId", "CreatedAt", "DestinationId", "InteractionType", "ModifiedAt", "SearchTerm", "TagId", "UserId", "Weight" },
                values: new object[,]
                {
                    { 1, 2, new DateTime(2026, 6, 1, 8, 0, 0, 0, DateTimeKind.Utc), null, 6, null, null, null, 4, 2.0 },
                    { 2, 1, new DateTime(2026, 6, 1, 8, 0, 0, 0, DateTimeKind.Utc), null, 6, null, null, null, 4, 2.0 },
                    { 3, null, new DateTime(2026, 6, 1, 8, 0, 0, 0, DateTimeKind.Utc), null, 6, null, null, 2, 4, 2.0 },
                    { 7, null, new DateTime(2026, 6, 8, 12, 0, 0, 0, DateTimeKind.Utc), null, 1, null, "waterfall", 2, 4, 1.0 },
                    { 8, 7, new DateTime(2026, 6, 9, 12, 0, 0, 0, DateTimeKind.Utc), null, 1, null, "old town", null, 4, 1.0 }
                });

            migrationBuilder.InsertData(
                table: "UserRoles",
                columns: new[] { "Id", "DateAssigned", "RoleId", "UserId" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, 1 },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, 2 },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, 3 },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 2, 4 },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 2, 5 }
                });

            migrationBuilder.InsertData(
                table: "Cities",
                columns: new[] { "Id", "CreatedAt", "ModifiedAt", "Name", "RegionId" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Sarajevo", 1 },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Mostar", 2 },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Blagaj", 2 },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Počitelj", 2 },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Konjic", 2 },
                    { 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Bihać", 3 },
                    { 7, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Cazin", 3 },
                    { 8, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Bosanska Krupa", 3 },
                    { 9, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Travnik", 4 },
                    { 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Jajce", 4 },
                    { 11, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Tuzla", 5 },
                    { 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Srebrenik", 5 },
                    { 13, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Zenica", 6 },
                    { 14, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Visoko", 6 },
                    { 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Doboj", 6 },
                    { 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Dubrovnik", 7 },
                    { 17, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, "Stolac", 2 }
                });

            migrationBuilder.InsertData(
                table: "Favorites",
                columns: new[] { "Id", "CreatedAt", "DestinationId", "ModifiedAt", "TourId", "UserId" },
                values: new object[] { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), null, null, 3, 4 });

            migrationBuilder.InsertData(
                table: "RoleApplications",
                columns: new[] { "Id", "CreatedAt", "DecidedAt", "DecidedByUserId", "Document", "DocumentContentType", "ModifiedAt", "Motivation", "RegionId", "RejectionReason", "RoleId", "Status", "UserId" },
                values: new object[] { 1, new DateTime(2026, 7, 12, 9, 0, 0, 0, DateTimeKind.Utc), null, null, null, null, null, "I am a local historian and want to contribute and maintain destinations from the Una-Sana region.", 3, null, 3, 0, 5 });

            migrationBuilder.InsertData(
                table: "TourSchedules",
                columns: new[] { "Id", "CancelledAt", "CancelledReason", "Capacity", "CreatedAt", "EndsAt", "ModifiedAt", "SeatsTaken", "StartsAt", "Status", "TourId" },
                values: new object[,]
                {
                    { 1, null, null, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 6, 20, 12, 0, 0, 0, DateTimeKind.Utc), null, 2, new DateTime(2026, 6, 20, 10, 0, 0, 0, DateTimeKind.Utc), 0, 1 },
                    { 2, null, null, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 15, 12, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 15, 10, 0, 0, 0, DateTimeKind.Utc), 0, 1 },
                    { 3, null, null, 15, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 10, 12, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 10, 10, 0, 0, 0, DateTimeKind.Utc), 0, 1 },
                    { 4, null, null, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 20, 14, 0, 0, 0, DateTimeKind.Utc), null, 2, new DateTime(2026, 8, 20, 9, 0, 0, 0, DateTimeKind.Utc), 0, 2 },
                    { 5, null, null, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 6, 25, 14, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 6, 25, 9, 0, 0, 0, DateTimeKind.Utc), 0, 2 },
                    { 6, null, null, 20, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 5, 12, 0, 0, 0, DateTimeKind.Utc), null, 1, new DateTime(2026, 8, 5, 9, 0, 0, 0, DateTimeKind.Utc), 0, 3 },
                    { 7, null, null, 20, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 5, 30, 12, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 5, 30, 9, 0, 0, 0, DateTimeKind.Utc), 0, 3 },
                    { 8, null, null, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 9, 1, 12, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 9, 1, 8, 0, 0, 0, DateTimeKind.Utc), 0, 4 },
                    { 9, null, null, 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 8, 25, 14, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 8, 25, 8, 0, 0, 0, DateTimeKind.Utc), 0, 5 },
                    { 10, null, null, 16, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), new DateTime(2026, 6, 10, 14, 0, 0, 0, DateTimeKind.Utc), null, 0, new DateTime(2026, 6, 10, 8, 0, 0, 0, DateTimeKind.Utc), 0, 5 }
                });

            migrationBuilder.InsertData(
                table: "Bookings",
                columns: new[] { "Id", "CancellationReason", "CancelledByUserId", "ConfirmedByUserId", "CreatedAt", "ExpiresAt", "ModifiedAt", "NumberOfPeople", "RejectionReason", "StatusChangedAt", "StatusId", "TotalAmount", "TourScheduleId", "UserId" },
                values: new object[,]
                {
                    { 1, null, null, 4, new DateTime(2026, 6, 15, 9, 0, 0, 0, DateTimeKind.Utc), null, null, 2, null, new DateTime(2026, 6, 20, 12, 30, 0, 0, DateTimeKind.Utc), 4, 50.00m, 1, 5 },
                    { 2, null, null, 5, new DateTime(2026, 7, 9, 15, 0, 0, 0, DateTimeKind.Utc), null, null, 1, null, new DateTime(2026, 7, 10, 11, 0, 0, 0, DateTimeKind.Utc), 3, 30.00m, 6, 4 },
                    { 3, "Change of travel plans.", 5, null, new DateTime(2026, 7, 1, 12, 0, 0, 0, DateTimeKind.Utc), null, null, 3, null, new DateTime(2026, 7, 5, 10, 0, 0, 0, DateTimeKind.Utc), 5, 120.00m, 9, 5 },
                    { 4, null, null, null, new DateTime(2026, 7, 14, 8, 0, 0, 0, DateTimeKind.Utc), null, null, 2, null, new DateTime(2026, 7, 14, 8, 0, 0, 0, DateTimeKind.Utc), 2, 90.00m, 4, 5 }
                });

            migrationBuilder.InsertData(
                table: "Destinations",
                columns: new[] { "Id", "AverageRating", "CategoryId", "CityId", "CreatedAt", "Description", "IsFeatured", "Latitude", "Longitude", "ModeratedAt", "ModeratedByUserId", "ModifiedAt", "Name", "RejectionReason", "Status", "SubmittedByUserId", "ViewCount" },
                values: new object[,]
                {
                    { 1, 4.5, 1, 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "The iconic 16th-century Ottoman bridge over the Neretva in Mostar, rebuilt after 1993 and a UNESCO World Heritage Site.", true, 43.337299999999999, 17.814900000000002, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Stari Most", null, 1, 4, 320 },
                    { 2, 5.0, 2, 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A wide natural amphitheatre of waterfalls on the Trebižat river, popular for swimming in summer.", true, 43.158299999999997, 17.600000000000001, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Kravice Waterfalls", null, 1, 4, 210 },
                    { 3, 0.0, 2, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "The spring of the river Bosna at the foot of Mount Igman, a landscaped park near Sarajevo.", false, 43.82, 18.260000000000002, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Vrelo Bosne", null, 1, 5, 95 },
                    { 4, 0.0, 1, 7, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A layered medieval-to-Ottoman fortress above the Una near Cazin.", false, 44.920000000000002, 15.98, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Ostrožac Castle", null, 1, 4, 40 },
                    { 5, 0.0, 7, 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "The historic core of Bihać on the Una, with the Fethija mosque and Captain's Tower.", false, 44.810000000000002, 15.869999999999999, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Bihać Old Town", null, 1, 5, 55 },
                    { 6, 0.0, 1, 12, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A 13th-century fortress on a rock spur, one of the best-preserved in Bosnia.", false, 44.700000000000003, 18.489999999999998, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Srebrenik Fortress", null, 1, 4, 30 },
                    { 7, 5.0, 3, 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A 16th-century dervish monastery built against a cliff at the source of the Buna river.", true, 43.256999999999998, 17.888000000000002, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Blagaj Tekija", null, 1, 5, 180 },
                    { 8, 0.0, 7, 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A stepped Ottoman-era village and fortress overlooking the Neretva valley.", false, 43.130000000000003, 17.73, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Počitelj", null, 1, 4, 70 },
                    { 9, 0.0, 2, 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A 20-metre waterfall where the Pliva meets the Vrbas in the heart of Jajce.", true, 44.340000000000003, 17.27, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Jajce Waterfall", null, 1, 5, 240 },
                    { 10, 0.0, 2, 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Protected river canyons, rapids and waterfalls around the upper Una — Bosnia's rafting heartland.", false, 44.649999999999999, 16.149999999999999, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Una National Park", null, 1, 4, 130 },
                    { 11, 4.0, 7, 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "Sarajevo's 15th-century Ottoman bazaar and cultural heart, full of coppersmiths and cafés.", true, 43.8596, 18.430599999999998, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, "Baščaršija", null, 1, 5, 260 },
                    { 12, 0.0, 1, 13, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), "A small medieval fortress guarding the Bosna gorge north of Zenica.", false, 44.280000000000001, 17.98, null, null, null, "Vranduk Fortress", null, 0, 5, 0 }
                });

            migrationBuilder.InsertData(
                table: "DestinationReviews",
                columns: new[] { "Id", "Comment", "CreatedAt", "DestinationId", "IsRemoved", "ModifiedAt", "Rating", "RemovalReason", "RemovedByUserId", "UserId" },
                values: new object[,]
                {
                    { 1, "Breathtaking bridge — a must-see, especially at sunset.", new DateTime(2026, 6, 21, 9, 0, 0, 0, DateTimeKind.Utc), 1, false, null, 5, null, null, 5 },
                    { 2, "Beautiful, but very crowded in summer.", new DateTime(2026, 6, 22, 9, 0, 0, 0, DateTimeKind.Utc), 1, false, null, 4, null, null, 4 },
                    { 3, "A magical, peaceful place right by the river source.", new DateTime(2026, 6, 23, 9, 0, 0, 0, DateTimeKind.Utc), 7, false, null, 5, null, null, 5 },
                    { 4, "Great atmosphere, coppersmiths and the best coffee.", new DateTime(2026, 6, 24, 9, 0, 0, 0, DateTimeKind.Utc), 11, false, null, 4, null, null, 4 },
                    { 5, "Amazing waterfalls, perfect for a hot summer day.", new DateTime(2026, 6, 25, 9, 0, 0, 0, DateTimeKind.Utc), 2, false, null, 5, null, null, 4 }
                });

            migrationBuilder.InsertData(
                table: "DestinationTags",
                columns: new[] { "DestinationId", "TagId" },
                values: new object[,]
                {
                    { 1, 1 },
                    { 1, 3 },
                    { 1, 6 },
                    { 1, 9 },
                    { 1, 14 },
                    { 2, 2 },
                    { 2, 6 },
                    { 2, 11 },
                    { 2, 12 },
                    { 3, 7 },
                    { 3, 8 },
                    { 3, 11 },
                    { 4, 4 },
                    { 4, 10 },
                    { 5, 3 },
                    { 5, 8 },
                    { 5, 14 },
                    { 6, 4 },
                    { 6, 10 },
                    { 7, 3 },
                    { 7, 6 },
                    { 7, 8 },
                    { 7, 13 },
                    { 8, 3 },
                    { 8, 10 },
                    { 8, 14 },
                    { 9, 2 },
                    { 9, 4 },
                    { 9, 11 },
                    { 10, 5 },
                    { 10, 8 },
                    { 10, 11 },
                    { 10, 12 },
                    { 11, 3 },
                    { 11, 14 },
                    { 11, 17 },
                    { 12, 4 },
                    { 12, 10 }
                });

            migrationBuilder.InsertData(
                table: "Favorites",
                columns: new[] { "Id", "CreatedAt", "DestinationId", "ModifiedAt", "TourId", "UserId" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, null, 4 },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 7, null, null, 4 },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 2, null, null, 5 }
                });

            migrationBuilder.InsertData(
                table: "Payments",
                columns: new[] { "Id", "Amount", "BookingId", "CreatedAt", "Currency", "ModifiedAt", "PlatformFeeAmount", "PlatformFeePercentage", "Status", "StripePaymentIntentId", "SucceededAt" },
                values: new object[,]
                {
                    { 1, 50.00m, 1, new DateTime(2026, 6, 15, 9, 0, 0, 0, DateTimeKind.Utc), "bam", null, 5.00m, 10.00m, 1, "pi_seed_0001", new DateTime(2026, 6, 15, 9, 1, 0, 0, DateTimeKind.Utc) },
                    { 2, 30.00m, 2, new DateTime(2026, 7, 9, 15, 0, 0, 0, DateTimeKind.Utc), "bam", null, 3.00m, 10.00m, 1, "pi_seed_0002", new DateTime(2026, 7, 9, 15, 1, 0, 0, DateTimeKind.Utc) },
                    { 3, 120.00m, 3, new DateTime(2026, 7, 1, 12, 0, 0, 0, DateTimeKind.Utc), "bam", null, 12.00m, 10.00m, 3, "pi_seed_0003", new DateTime(2026, 7, 1, 12, 1, 0, 0, DateTimeKind.Utc) },
                    { 4, 90.00m, 4, new DateTime(2026, 7, 14, 8, 0, 0, 0, DateTimeKind.Utc), "bam", null, 9.00m, 10.00m, 1, "pi_seed_0004", new DateTime(2026, 7, 14, 8, 1, 0, 0, DateTimeKind.Utc) }
                });

            migrationBuilder.InsertData(
                table: "TourDestinations",
                columns: new[] { "Id", "CreatedAt", "DestinationId", "ModifiedAt", "SortOrder", "TourId" },
                values: new object[,]
                {
                    { 1, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 1, null, 1, 1 },
                    { 2, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 7, null, 2, 1 },
                    { 3, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 2, null, 1, 2 },
                    { 4, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 8, null, 2, 2 },
                    { 5, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 3, null, 1, 3 },
                    { 6, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 11, null, 2, 3 },
                    { 7, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 10, null, 1, 4 },
                    { 8, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 5, null, 2, 4 },
                    { 9, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 7, null, 1, 5 },
                    { 10, new DateTime(2026, 3, 9, 0, 0, 0, 0, DateTimeKind.Utc), 8, null, 2, 5 }
                });

            migrationBuilder.InsertData(
                table: "TourReviews",
                columns: new[] { "Id", "BookingId", "Comment", "CreatedAt", "IsRemoved", "ModifiedAt", "Rating", "RemovalReason", "RemovedByUserId", "TourId", "UserId" },
                values: new object[] { 1, 1, "Fantastic guide and a perfect route across the old town.", new DateTime(2026, 6, 21, 10, 0, 0, 0, DateTimeKind.Utc), false, null, 5, null, null, 1, 5 });

            migrationBuilder.InsertData(
                table: "UserInteractions",
                columns: new[] { "Id", "CategoryId", "CreatedAt", "DestinationId", "InteractionType", "ModifiedAt", "SearchTerm", "TagId", "UserId", "Weight" },
                values: new object[,]
                {
                    { 4, null, new DateTime(2026, 6, 5, 12, 0, 0, 0, DateTimeKind.Utc), 1, 0, null, null, null, 4, 1.0 },
                    { 5, null, new DateTime(2026, 6, 6, 12, 0, 0, 0, DateTimeKind.Utc), 2, 0, null, null, null, 4, 1.0 },
                    { 6, null, new DateTime(2026, 6, 7, 12, 0, 0, 0, DateTimeKind.Utc), 9, 0, null, null, null, 4, 1.0 },
                    { 9, null, new DateTime(2026, 6, 10, 12, 0, 0, 0, DateTimeKind.Utc), 1, 2, null, null, null, 4, 3.0 },
                    { 10, null, new DateTime(2026, 6, 11, 12, 0, 0, 0, DateTimeKind.Utc), 7, 2, null, null, null, 4, 3.0 },
                    { 11, null, new DateTime(2026, 6, 20, 13, 0, 0, 0, DateTimeKind.Utc), 1, 4, null, null, null, 5, 5.0 },
                    { 12, null, new DateTime(2026, 6, 21, 9, 30, 0, 0, DateTimeKind.Utc), 1, 5, null, null, null, 5, 3.0 }
                });

            migrationBuilder.InsertData(
                table: "Refunds",
                columns: new[] { "Id", "Amount", "CreatedAt", "InitiatedByUserId", "ModifiedAt", "PaymentId", "PercentageApplied", "Reason", "StripeRefundId" },
                values: new object[] { 1, 120.00m, new DateTime(2026, 7, 5, 10, 0, 0, 0, DateTimeKind.Utc), 5, null, 3, 100, "User cancellation more than 72 hours before start.", "re_seed_0001" });

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_CancelledByUserId",
                table: "Bookings",
                column: "CancelledByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_ConfirmedByUserId",
                table: "Bookings",
                column: "ConfirmedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_StatusId",
                table: "Bookings",
                column: "StatusId");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_TourScheduleId",
                table: "Bookings",
                column: "TourScheduleId");

            migrationBuilder.CreateIndex(
                name: "IX_Bookings_UserId_TourScheduleId",
                table: "Bookings",
                columns: new[] { "UserId", "TourScheduleId" },
                unique: true,
                filter: "[StatusId] IN (1, 2, 3)");

            migrationBuilder.CreateIndex(
                name: "IX_BookingStatuses_Name",
                table: "BookingStatuses",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Cities_RegionId_Name",
                table: "Cities",
                columns: new[] { "RegionId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Countries_Name",
                table: "Countries",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DestinationCategories_Name",
                table: "DestinationCategories",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DestinationImages_DestinationId",
                table: "DestinationImages",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_DestinationReviews_DestinationId",
                table: "DestinationReviews",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_DestinationReviews_RemovedByUserId",
                table: "DestinationReviews",
                column: "RemovedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_DestinationReviews_UserId",
                table: "DestinationReviews",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_CategoryId_Status",
                table: "Destinations",
                columns: new[] { "CategoryId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_CityId",
                table: "Destinations",
                column: "CityId");

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_ModeratedByUserId",
                table: "Destinations",
                column: "ModeratedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_Name",
                table: "Destinations",
                column: "Name");

            migrationBuilder.CreateIndex(
                name: "IX_Destinations_SubmittedByUserId",
                table: "Destinations",
                column: "SubmittedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_DestinationTags_TagId",
                table: "DestinationTags",
                column: "TagId");

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_DestinationId",
                table: "Favorites",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_TourId",
                table: "Favorites",
                column: "TourId");

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_UserId_DestinationId",
                table: "Favorites",
                columns: new[] { "UserId", "DestinationId" },
                unique: true,
                filter: "[DestinationId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Favorites_UserId_TourId",
                table: "Favorites",
                columns: new[] { "UserId", "TourId" },
                unique: true,
                filter: "[TourId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Notifications_UserId_IsRead",
                table: "Notifications",
                columns: new[] { "UserId", "IsRead" });

            migrationBuilder.CreateIndex(
                name: "IX_PasswordResetCodes_UserId",
                table: "PasswordResetCodes",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_BookingId",
                table: "Payments",
                column: "BookingId");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_StripePaymentIntentId",
                table: "Payments",
                column: "StripePaymentIntentId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationLogs_DestinationId",
                table: "RecommendationLogs",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationLogs_UserId",
                table: "RecommendationLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_RefreshTokens_UserId",
                table: "RefreshTokens",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Refunds_InitiatedByUserId",
                table: "Refunds",
                column: "InitiatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Refunds_PaymentId",
                table: "Refunds",
                column: "PaymentId");

            migrationBuilder.CreateIndex(
                name: "IX_Regions_CountryId_Name",
                table: "Regions",
                columns: new[] { "CountryId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RoleApplications_DecidedByUserId",
                table: "RoleApplications",
                column: "DecidedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RoleApplications_RegionId",
                table: "RoleApplications",
                column: "RegionId");

            migrationBuilder.CreateIndex(
                name: "IX_RoleApplications_RoleId",
                table: "RoleApplications",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_RoleApplications_UserId",
                table: "RoleApplications",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Tags_Name",
                table: "Tags",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TourDestinations_DestinationId",
                table: "TourDestinations",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_TourDestinations_TourId_DestinationId",
                table: "TourDestinations",
                columns: new[] { "TourId", "DestinationId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TourReviews_BookingId",
                table: "TourReviews",
                column: "BookingId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TourReviews_RemovedByUserId",
                table: "TourReviews",
                column: "RemovedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TourReviews_TourId",
                table: "TourReviews",
                column: "TourId");

            migrationBuilder.CreateIndex(
                name: "IX_TourReviews_UserId",
                table: "TourReviews",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Tours_OrganizerId",
                table: "Tours",
                column: "OrganizerId");

            migrationBuilder.CreateIndex(
                name: "IX_Tours_TourTypeId",
                table: "Tours",
                column: "TourTypeId");

            migrationBuilder.CreateIndex(
                name: "IX_TourSchedules_StartsAt",
                table: "TourSchedules",
                column: "StartsAt");

            migrationBuilder.CreateIndex(
                name: "IX_TourSchedules_TourId",
                table: "TourSchedules",
                column: "TourId");

            migrationBuilder.CreateIndex(
                name: "IX_TourTypes_Name",
                table: "TourTypes",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserInteractions_CategoryId",
                table: "UserInteractions",
                column: "CategoryId");

            migrationBuilder.CreateIndex(
                name: "IX_UserInteractions_DestinationId",
                table: "UserInteractions",
                column: "DestinationId");

            migrationBuilder.CreateIndex(
                name: "IX_UserInteractions_TagId",
                table: "UserInteractions",
                column: "TagId");

            migrationBuilder.CreateIndex(
                name: "IX_UserInteractions_UserId_CreatedAt",
                table: "UserInteractions",
                columns: new[] { "UserId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_RoleId",
                table: "UserRoles",
                column: "RoleId");

            migrationBuilder.CreateIndex(
                name: "IX_UserRoles_UserId",
                table: "UserRoles",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DestinationImages");

            migrationBuilder.DropTable(
                name: "DestinationReviews");

            migrationBuilder.DropTable(
                name: "DestinationTags");

            migrationBuilder.DropTable(
                name: "Favorites");

            migrationBuilder.DropTable(
                name: "Notifications");

            migrationBuilder.DropTable(
                name: "PasswordResetCodes");

            migrationBuilder.DropTable(
                name: "RecommendationLogs");

            migrationBuilder.DropTable(
                name: "RefreshTokens");

            migrationBuilder.DropTable(
                name: "RefundPolicyTiers");

            migrationBuilder.DropTable(
                name: "Refunds");

            migrationBuilder.DropTable(
                name: "RoleApplications");

            migrationBuilder.DropTable(
                name: "TourDestinations");

            migrationBuilder.DropTable(
                name: "TourReviews");

            migrationBuilder.DropTable(
                name: "UserInteractions");

            migrationBuilder.DropTable(
                name: "UserRoles");

            migrationBuilder.DropTable(
                name: "Payments");

            migrationBuilder.DropTable(
                name: "Destinations");

            migrationBuilder.DropTable(
                name: "Tags");

            migrationBuilder.DropTable(
                name: "Roles");

            migrationBuilder.DropTable(
                name: "Bookings");

            migrationBuilder.DropTable(
                name: "Cities");

            migrationBuilder.DropTable(
                name: "DestinationCategories");

            migrationBuilder.DropTable(
                name: "BookingStatuses");

            migrationBuilder.DropTable(
                name: "TourSchedules");

            migrationBuilder.DropTable(
                name: "Regions");

            migrationBuilder.DropTable(
                name: "Tours");

            migrationBuilder.DropTable(
                name: "Countries");

            migrationBuilder.DropTable(
                name: "TourTypes");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
