using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Database
{
    public partial class TravleDbContext : DbContext
    {
        /// <summary>
        /// Deterministic seed timestamp for reference/base rows. Runtime rows (schedules, bookings,
        /// payments) carry their own realistic dates. Kept static so every <c>HasData</c> row is stable
        /// across migrations (a changing value would produce spurious model diffs).
        /// </summary>
        private static readonly DateTime SeedDate = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc);

        private void CreateSeed(ModelBuilder modelBuilder)
        {
            SeedRoles(modelBuilder);
            SeedUsers(modelBuilder);
            SeedUserRoles(modelBuilder);

            // Reference data (HasData, per 03 §7).
            SeedCountries(modelBuilder);
            SeedRegions(modelBuilder);
            SeedCities(modelBuilder);
            SeedDestinationCategories(modelBuilder);
            SeedTourTypes(modelBuilder);
            SeedTags(modelBuilder);
            SeedBookingStatuses(modelBuilder);
            SeedRefundPolicyTiers(modelBuilder);

            // Main domain (representative rows so every screen has data on first run; images and the
            // heavy 25–40 destination set land with the runtime image seeder in a later phase).
            SeedDestinations(modelBuilder);
            SeedDestinationTags(modelBuilder);
            SeedTours(modelBuilder);
            SeedTourDestinations(modelBuilder);
            SeedTourSchedules(modelBuilder);
            SeedBookings(modelBuilder);
            SeedPayments(modelBuilder);
            SeedRefunds(modelBuilder);
            SeedDestinationReviews(modelBuilder);
            SeedTourReviews(modelBuilder);
            SeedFavorites(modelBuilder);
            SeedUserInteractions(modelBuilder);
            SeedRoleApplications(modelBuilder);
            SeedNotifications(modelBuilder);
        }

        private void SeedRoles(ModelBuilder modelBuilder)
        {
            // Seed Roles - deterministic Ids: 1 = Admin, 2 = Customer
            modelBuilder.Entity<Role>().HasData(
                new
                {
                    Id = 1,
                    Name = "Admin",
                    Description = "Administrator role with full permissions",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 2,
                    Name = "Customer",
                    Description = "Default customer role",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                // Travle domain roles (referenced by RoleApplications and by tours/destinations
                // ownership). Traveler-vs-Customer renaming and the four demo accounts are Phase 1 work.
                new
                {
                    Id = 3,
                    Name = "Curator",
                    Description = "Submits and curates tourist destinations",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 4,
                    Name = "Organizer",
                    Description = "Creates and manages tours and schedules",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                }
            );
        }

        private void SeedUsers(ModelBuilder modelBuilder)
        {
            // Seed Users - 3 admins (Ids 1-3) and 2 customers (Ids 4-5)
            modelBuilder.Entity<User>().HasData(
                new
                {
                    Id = 1,
                    FirstName = "Alice",
                    LastName = "Admin",
                    Email = "admin1@gmail.com",
                    Username = "admin1",
                    PasswordHash = "5kRBQg4Ufcx4hAknG7P9zhfLPvY=", // Test123
                    PasswordSalt = "FmvmUwPsJyRRffhNRQvbrA==",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc),
                    LastLoginAt = (DateTime?)null,
                    PhoneNumber = (string?)null
                },
                new
                {
                    Id = 2,
                    FirstName = "Bob",
                    LastName = "Admin",
                    Email = "admin2@gmail.com",
                    Username = "admin2",
                    PasswordHash = "GBoyh1WP+OMgGjqRj6vK6L1+oGc=", // Test123
                    PasswordSalt = "0AXpKx6xRp9xM42jCf/PiA==",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc),
                    LastLoginAt = (DateTime?)null,
                    PhoneNumber = (string?)null
                },
                new
                {
                    Id = 3,
                    FirstName = "Carol",
                    LastName = "Admin",
                    Email = "admin3@gmail.com",
                    Username = "admin3",
                    PasswordHash = "x6JHKCTQywdAzTcZxGWFvrKPORM=", // Test123
                    PasswordSalt = "IwhTfKQNgyqWfOlTqCDXrg==",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc),
                    LastLoginAt = (DateTime?)null,
                    PhoneNumber = (string?)null
                },
                new
                {
                    Id = 4,
                    FirstName = "Dave",
                    LastName = "Customer",
                    Email = "customer1@gmail.com",
                    Username = "customer1",
                    PasswordHash = "E0fA2/f9GZvIRRt/cgqQemG/Cog=", // Test123
                    PasswordSalt = "TiJxWTJcd7sBSiWNbhK9Vw==",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc),
                    LastLoginAt = (DateTime?)null,
                    PhoneNumber = (string?)null
                },
                new
                {
                    Id = 5,
                    FirstName = "Eve",
                    LastName = "Customer",
                    Email = "customer2@gmail.com",
                    Username = "customer2",
                    PasswordHash = "Ov4LxpWKXXV9dwMYvBgqODdzIt0=", // Test123
                    PasswordSalt = "KtWF6g7SemBqs4nVWV4Ziw==",
                    IsActive = true,
                    CreatedAt = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc),
                    LastLoginAt = (DateTime?)null,
                    PhoneNumber = (string?)null
                }
            );
        }

        private void SeedUserRoles(ModelBuilder modelBuilder)
        {
            // Map users to roles (UserRole has its own Id PK)
            // Admin role = RoleId 1, Customer role = RoleId 2
            modelBuilder.Entity<UserRole>().HasData(
                new
                {
                    Id = 1,
                    UserId = 1,
                    RoleId = 1,
                    DateAssigned = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 2,
                    UserId = 2,
                    RoleId = 1,
                    DateAssigned = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 3,
                    UserId = 3,
                    RoleId = 1,
                    DateAssigned = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 4,
                    UserId = 4,
                    RoleId = 2,
                    DateAssigned = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                },
                new
                {
                    Id = 5,
                    UserId = 5,
                    RoleId = 2,
                    DateAssigned = new DateTime(2026, 3, 9, 0, 0, 0, DateTimeKind.Utc)
                }
            );
        }

        private void SeedCountries(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Country>().HasData(
                new { Id = 1, Name = "Bosnia and Herzegovina", CreatedAt = SeedDate },
                new { Id = 2, Name = "Croatia", CreatedAt = SeedDate }
            );
        }

        private void SeedRegions(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Region>().HasData(
                new { Id = 1, Name = "Sarajevo Canton", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 2, Name = "Herzegovina-Neretva", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 3, Name = "Una-Sana", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 4, Name = "Central Bosnia", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 5, Name = "Tuzla", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 6, Name = "Zenica-Doboj", CountryId = 1, CreatedAt = SeedDate },
                new { Id = 7, Name = "Dubrovnik-Neretva", CountryId = 2, CreatedAt = SeedDate }
            );
        }

        private void SeedCities(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<City>().HasData(
                new { Id = 1, Name = "Sarajevo", RegionId = 1, CreatedAt = SeedDate },
                new { Id = 2, Name = "Mostar", RegionId = 2, CreatedAt = SeedDate },
                new { Id = 3, Name = "Blagaj", RegionId = 2, CreatedAt = SeedDate },
                new { Id = 4, Name = "Počitelj", RegionId = 2, CreatedAt = SeedDate },
                new { Id = 5, Name = "Konjic", RegionId = 2, CreatedAt = SeedDate },
                new { Id = 6, Name = "Bihać", RegionId = 3, CreatedAt = SeedDate },
                new { Id = 7, Name = "Cazin", RegionId = 3, CreatedAt = SeedDate },
                new { Id = 8, Name = "Bosanska Krupa", RegionId = 3, CreatedAt = SeedDate },
                new { Id = 9, Name = "Travnik", RegionId = 4, CreatedAt = SeedDate },
                new { Id = 10, Name = "Jajce", RegionId = 4, CreatedAt = SeedDate },
                new { Id = 11, Name = "Tuzla", RegionId = 5, CreatedAt = SeedDate },
                new { Id = 12, Name = "Srebrenik", RegionId = 5, CreatedAt = SeedDate },
                new { Id = 13, Name = "Zenica", RegionId = 6, CreatedAt = SeedDate },
                new { Id = 14, Name = "Visoko", RegionId = 6, CreatedAt = SeedDate },
                new { Id = 15, Name = "Doboj", RegionId = 6, CreatedAt = SeedDate },
                new { Id = 16, Name = "Dubrovnik", RegionId = 7, CreatedAt = SeedDate },
                new { Id = 17, Name = "Stolac", RegionId = 2, CreatedAt = SeedDate }
            );
        }

        private void SeedDestinationCategories(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<DestinationCategory>().HasData(
                new { Id = 1, Name = "Historical Site", CreatedAt = SeedDate },
                new { Id = 2, Name = "Natural Wonder", CreatedAt = SeedDate },
                new { Id = 3, Name = "Religious Site", CreatedAt = SeedDate },
                new { Id = 4, Name = "Cultural Landmark", CreatedAt = SeedDate },
                new { Id = 5, Name = "Adventure", CreatedAt = SeedDate },
                new { Id = 6, Name = "Museum", CreatedAt = SeedDate },
                new { Id = 7, Name = "Old Town", CreatedAt = SeedDate }
            );
        }

        private void SeedTourTypes(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TourType>().HasData(
                new { Id = 1, Name = "Walking Tour", CreatedAt = SeedDate },
                new { Id = 2, Name = "Cultural Tour", CreatedAt = SeedDate },
                new { Id = 3, Name = "Adventure Tour", CreatedAt = SeedDate },
                new { Id = 4, Name = "Food Tour", CreatedAt = SeedDate },
                new { Id = 5, Name = "Private Tour", CreatedAt = SeedDate }
            );
        }

        private void SeedTags(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Tag>().HasData(
                new { Id = 1, Name = "UNESCO", CreatedAt = SeedDate },
                new { Id = 2, Name = "Waterfall", CreatedAt = SeedDate },
                new { Id = 3, Name = "Ottoman", CreatedAt = SeedDate },
                new { Id = 4, Name = "Medieval", CreatedAt = SeedDate },
                new { Id = 5, Name = "Hiking", CreatedAt = SeedDate },
                new { Id = 6, Name = "Photography", CreatedAt = SeedDate },
                new { Id = 7, Name = "Family Friendly", CreatedAt = SeedDate },
                new { Id = 8, Name = "River", CreatedAt = SeedDate },
                new { Id = 9, Name = "Bridge", CreatedAt = SeedDate },
                new { Id = 10, Name = "Fortress", CreatedAt = SeedDate },
                new { Id = 11, Name = "Nature", CreatedAt = SeedDate },
                new { Id = 12, Name = "Swimming", CreatedAt = SeedDate },
                new { Id = 13, Name = "Pilgrimage", CreatedAt = SeedDate },
                new { Id = 14, Name = "Old Town", CreatedAt = SeedDate },
                new { Id = 15, Name = "Mountains", CreatedAt = SeedDate },
                new { Id = 16, Name = "Museum", CreatedAt = SeedDate },
                new { Id = 17, Name = "Architecture", CreatedAt = SeedDate }
            );
        }

        private void SeedBookingStatuses(ModelBuilder modelBuilder)
        {
            // Ids are load-bearing: the filtered unique index on Bookings references 1/2/3 and the
            // state machine matches on these names. Do not renumber or rename.
            modelBuilder.Entity<BookingStatus>().HasData(
                new { Id = 1, Name = "PaymentInProgress", CreatedAt = SeedDate },
                new { Id = 2, Name = "Pending", CreatedAt = SeedDate },
                new { Id = 3, Name = "Confirmed", CreatedAt = SeedDate },
                new { Id = 4, Name = "Completed", CreatedAt = SeedDate },
                new { Id = 5, Name = "Cancelled", CreatedAt = SeedDate },
                new { Id = 6, Name = "Expired", CreatedAt = SeedDate }
            );
        }

        private void SeedRefundPolicyTiers(ModelBuilder modelBuilder)
        {
            // Global ladder for user cancellations (03 §refunds). HoursBeforeMax null = unbounded.
            modelBuilder.Entity<RefundPolicyTier>().HasData(
                new { Id = 1, HoursBeforeMin = 72, HoursBeforeMax = (int?)null, Percentage = 100, CreatedAt = SeedDate },
                new { Id = 2, HoursBeforeMin = 24, HoursBeforeMax = (int?)72, Percentage = 50, CreatedAt = SeedDate },
                new { Id = 3, HoursBeforeMin = 1, HoursBeforeMax = (int?)24, Percentage = 25, CreatedAt = SeedDate },
                new { Id = 4, HoursBeforeMin = 0, HoursBeforeMax = (int?)1, Percentage = 0, CreatedAt = SeedDate }
            );
        }

        private void SeedDestinations(ModelBuilder modelBuilder)
        {
            // Submitters are the two demo travelers (Ids 4/5); moderator is admin (Id 1). Real
            // curator/organizer accounts arrive in Phase 1. Denormalized AverageRating matches the
            // seeded reviews below; ViewCount gives the popularity term something to work with.
            modelBuilder.Entity<Destination>().HasData(
                new { Id = 1, Name = "Stari Most", Description = "The iconic 16th-century Ottoman bridge over the Neretva in Mostar, rebuilt after 1993 and a UNESCO World Heritage Site.", CategoryId = 1, CityId = 2, Latitude = 43.3373, Longitude = 17.8149, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = true, AverageRating = 4.5, ViewCount = 320, CreatedAt = SeedDate },
                new { Id = 2, Name = "Kravice Waterfalls", Description = "A wide natural amphitheatre of waterfalls on the Trebižat river, popular for swimming in summer.", CategoryId = 2, CityId = 2, Latitude = 43.1583, Longitude = 17.6000, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = true, AverageRating = 5.0, ViewCount = 210, CreatedAt = SeedDate },
                new { Id = 3, Name = "Vrelo Bosne", Description = "The spring of the river Bosna at the foot of Mount Igman, a landscaped park near Sarajevo.", CategoryId = 2, CityId = 1, Latitude = 43.8200, Longitude = 18.2600, SubmittedByUserId = 5, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 95, CreatedAt = SeedDate },
                new { Id = 4, Name = "Ostrožac Castle", Description = "A layered medieval-to-Ottoman fortress above the Una near Cazin.", CategoryId = 1, CityId = 7, Latitude = 44.9200, Longitude = 15.9800, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 40, CreatedAt = SeedDate },
                new { Id = 5, Name = "Bihać Old Town", Description = "The historic core of Bihać on the Una, with the Fethija mosque and Captain's Tower.", CategoryId = 7, CityId = 6, Latitude = 44.8100, Longitude = 15.8700, SubmittedByUserId = 5, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 55, CreatedAt = SeedDate },
                new { Id = 6, Name = "Srebrenik Fortress", Description = "A 13th-century fortress on a rock spur, one of the best-preserved in Bosnia.", CategoryId = 1, CityId = 12, Latitude = 44.7000, Longitude = 18.4900, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 30, CreatedAt = SeedDate },
                new { Id = 7, Name = "Blagaj Tekija", Description = "A 16th-century dervish monastery built against a cliff at the source of the Buna river.", CategoryId = 3, CityId = 3, Latitude = 43.2570, Longitude = 17.8880, SubmittedByUserId = 5, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = true, AverageRating = 5.0, ViewCount = 180, CreatedAt = SeedDate },
                new { Id = 8, Name = "Počitelj", Description = "A stepped Ottoman-era village and fortress overlooking the Neretva valley.", CategoryId = 7, CityId = 4, Latitude = 43.1300, Longitude = 17.7300, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 70, CreatedAt = SeedDate },
                new { Id = 9, Name = "Jajce Waterfall", Description = "A 20-metre waterfall where the Pliva meets the Vrbas in the heart of Jajce.", CategoryId = 2, CityId = 10, Latitude = 44.3400, Longitude = 17.2700, SubmittedByUserId = 5, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = true, AverageRating = 0.0, ViewCount = 240, CreatedAt = SeedDate },
                new { Id = 10, Name = "Una National Park", Description = "Protected river canyons, rapids and waterfalls around the upper Una — Bosnia's rafting heartland.", CategoryId = 2, CityId = 6, Latitude = 44.6500, Longitude = 16.1500, SubmittedByUserId = 4, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = false, AverageRating = 0.0, ViewCount = 130, CreatedAt = SeedDate },
                new { Id = 11, Name = "Baščaršija", Description = "Sarajevo's 15th-century Ottoman bazaar and cultural heart, full of coppersmiths and cafés.", CategoryId = 7, CityId = 1, Latitude = 43.8596, Longitude = 18.4306, SubmittedByUserId = 5, Status = DestinationStatus.Approved, ModeratedByUserId = (int?)1, ModeratedAt = (DateTime?)SeedDate, IsFeatured = true, AverageRating = 4.0, ViewCount = 260, CreatedAt = SeedDate },
                // One Pending submission so the moderation queue is non-empty on first run.
                new { Id = 12, Name = "Vranduk Fortress", Description = "A small medieval fortress guarding the Bosna gorge north of Zenica.", CategoryId = 1, CityId = 13, Latitude = 44.2800, Longitude = 17.9800, SubmittedByUserId = 5, Status = DestinationStatus.Pending, ModeratedByUserId = (int?)null, ModeratedAt = (DateTime?)null, IsFeatured = false, AverageRating = 0.0, ViewCount = 0, CreatedAt = SeedDate }
            );
        }

        private void SeedDestinationTags(ModelBuilder modelBuilder)
        {
            // Bare composite-key link rows (no Id / timestamps).
            modelBuilder.Entity<DestinationTag>().HasData(
                new { DestinationId = 1, TagId = 1 }, new { DestinationId = 1, TagId = 3 }, new { DestinationId = 1, TagId = 9 }, new { DestinationId = 1, TagId = 14 }, new { DestinationId = 1, TagId = 6 },
                new { DestinationId = 2, TagId = 2 }, new { DestinationId = 2, TagId = 11 }, new { DestinationId = 2, TagId = 12 }, new { DestinationId = 2, TagId = 6 },
                new { DestinationId = 3, TagId = 11 }, new { DestinationId = 3, TagId = 8 }, new { DestinationId = 3, TagId = 7 },
                new { DestinationId = 4, TagId = 4 }, new { DestinationId = 4, TagId = 10 },
                new { DestinationId = 5, TagId = 14 }, new { DestinationId = 5, TagId = 3 }, new { DestinationId = 5, TagId = 8 },
                new { DestinationId = 6, TagId = 4 }, new { DestinationId = 6, TagId = 10 },
                new { DestinationId = 7, TagId = 3 }, new { DestinationId = 7, TagId = 13 }, new { DestinationId = 7, TagId = 8 }, new { DestinationId = 7, TagId = 6 },
                new { DestinationId = 8, TagId = 3 }, new { DestinationId = 8, TagId = 14 }, new { DestinationId = 8, TagId = 10 },
                new { DestinationId = 9, TagId = 2 }, new { DestinationId = 9, TagId = 4 }, new { DestinationId = 9, TagId = 11 },
                new { DestinationId = 10, TagId = 8 }, new { DestinationId = 10, TagId = 11 }, new { DestinationId = 10, TagId = 5 }, new { DestinationId = 10, TagId = 12 },
                new { DestinationId = 11, TagId = 3 }, new { DestinationId = 11, TagId = 14 }, new { DestinationId = 11, TagId = 17 },
                new { DestinationId = 12, TagId = 4 }, new { DestinationId = 12, TagId = 10 }
            );
        }

        private void SeedTours(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Tour>().HasData(
                new { Id = 1, OrganizerId = 4, Name = "Mostar Old Town Walking Tour", Description = "A guided walk across Stari Most and through the old bazaar, ending at Blagaj Tekija.", DurationMinutes = 120, PricePerPerson = 25.00m, Capacity = 15, TourTypeId = 1, IsActive = true, CreatedAt = SeedDate },
                new { Id = 2, OrganizerId = 4, Name = "Kravice Waterfalls Day Trip", Description = "A full-day excursion to the Kravice waterfalls with a stop in Počitelj.", DurationMinutes = 300, PricePerPerson = 45.00m, Capacity = 12, TourTypeId = 3, IsActive = true, CreatedAt = SeedDate },
                new { Id = 3, OrganizerId = 5, Name = "Sarajevo Cultural Heritage Tour", Description = "From Vrelo Bosne to Baščaršija — the natural and Ottoman heritage around Sarajevo.", DurationMinutes = 180, PricePerPerson = 30.00m, Capacity = 20, TourTypeId = 2, IsActive = true, CreatedAt = SeedDate },
                new { Id = 4, OrganizerId = 5, Name = "Una National Park Rafting", Description = "A guided rafting descent of the upper Una with a visit to Bihać old town.", DurationMinutes = 240, PricePerPerson = 60.00m, Capacity = 10, TourTypeId = 3, IsActive = true, CreatedAt = SeedDate },
                new { Id = 5, OrganizerId = 4, Name = "Blagaj & Počitelj Excursion", Description = "A half-day cultural excursion to the Buna spring and the fortress village of Počitelj.", DurationMinutes = 360, PricePerPerson = 40.00m, Capacity = 16, TourTypeId = 2, IsActive = true, CreatedAt = SeedDate }
            );
        }

        private void SeedTourDestinations(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<TourDestination>().HasData(
                new { Id = 1, TourId = 1, DestinationId = 1, SortOrder = 1, CreatedAt = SeedDate },
                new { Id = 2, TourId = 1, DestinationId = 7, SortOrder = 2, CreatedAt = SeedDate },
                new { Id = 3, TourId = 2, DestinationId = 2, SortOrder = 1, CreatedAt = SeedDate },
                new { Id = 4, TourId = 2, DestinationId = 8, SortOrder = 2, CreatedAt = SeedDate },
                new { Id = 5, TourId = 3, DestinationId = 3, SortOrder = 1, CreatedAt = SeedDate },
                new { Id = 6, TourId = 3, DestinationId = 11, SortOrder = 2, CreatedAt = SeedDate },
                new { Id = 7, TourId = 4, DestinationId = 10, SortOrder = 1, CreatedAt = SeedDate },
                new { Id = 8, TourId = 4, DestinationId = 5, SortOrder = 2, CreatedAt = SeedDate },
                new { Id = 9, TourId = 5, DestinationId = 7, SortOrder = 1, CreatedAt = SeedDate },
                new { Id = 10, TourId = 5, DestinationId = 8, SortOrder = 2, CreatedAt = SeedDate }
            );
        }

        private void SeedTourSchedules(ModelBuilder modelBuilder)
        {
            // Mix of past and future slots (relative to mid-2026). SeatsTaken reflects the seeded
            // bookings below (Pending/Confirmed/Completed hold seats; the cancelled one released its seats).
            modelBuilder.Entity<TourSchedule>().HasData(
                new { Id = 1, TourId = 1, StartsAt = new DateTime(2026, 6, 20, 10, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 6, 20, 12, 0, 0, DateTimeKind.Utc), Capacity = 15, SeatsTaken = 2, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 2, TourId = 1, StartsAt = new DateTime(2026, 8, 15, 10, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 8, 15, 12, 0, 0, DateTimeKind.Utc), Capacity = 15, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 3, TourId = 1, StartsAt = new DateTime(2026, 9, 10, 10, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 9, 10, 12, 0, 0, DateTimeKind.Utc), Capacity = 15, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 4, TourId = 2, StartsAt = new DateTime(2026, 8, 20, 9, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 8, 20, 14, 0, 0, DateTimeKind.Utc), Capacity = 12, SeatsTaken = 2, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 5, TourId = 2, StartsAt = new DateTime(2026, 6, 25, 9, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 6, 25, 14, 0, 0, DateTimeKind.Utc), Capacity = 12, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 6, TourId = 3, StartsAt = new DateTime(2026, 8, 5, 9, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 8, 5, 12, 0, 0, DateTimeKind.Utc), Capacity = 20, SeatsTaken = 1, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 7, TourId = 3, StartsAt = new DateTime(2026, 5, 30, 9, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 5, 30, 12, 0, 0, DateTimeKind.Utc), Capacity = 20, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 8, TourId = 4, StartsAt = new DateTime(2026, 9, 1, 8, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 9, 1, 12, 0, 0, DateTimeKind.Utc), Capacity = 10, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 9, TourId = 5, StartsAt = new DateTime(2026, 8, 25, 8, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 8, 25, 14, 0, 0, DateTimeKind.Utc), Capacity = 16, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate },
                new { Id = 10, TourId = 5, StartsAt = new DateTime(2026, 6, 10, 8, 0, 0, DateTimeKind.Utc), EndsAt = new DateTime(2026, 6, 10, 14, 0, 0, DateTimeKind.Utc), Capacity = 16, SeatsTaken = 0, Status = ScheduleStatus.Active, CreatedAt = SeedDate }
            );
        }

        private void SeedBookings(ModelBuilder modelBuilder)
        {
            // One booking in each of the demonstrable statuses (Completed, Confirmed, Cancelled, Pending),
            // so the state machine, reviews, refunds and history screens all have data.
            modelBuilder.Entity<Booking>().HasData(
                new { Id = 1, UserId = 5, TourScheduleId = 1, NumberOfPeople = 2, TotalAmount = 50.00m, StatusId = 4, StatusChangedAt = new DateTime(2026, 6, 20, 12, 30, 0, DateTimeKind.Utc), ConfirmedByUserId = (int?)4, CreatedAt = new DateTime(2026, 6, 15, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 2, UserId = 4, TourScheduleId = 6, NumberOfPeople = 1, TotalAmount = 30.00m, StatusId = 3, StatusChangedAt = new DateTime(2026, 7, 10, 11, 0, 0, DateTimeKind.Utc), ConfirmedByUserId = (int?)5, CreatedAt = new DateTime(2026, 7, 9, 15, 0, 0, DateTimeKind.Utc) },
                new { Id = 3, UserId = 5, TourScheduleId = 9, NumberOfPeople = 3, TotalAmount = 120.00m, StatusId = 5, StatusChangedAt = new DateTime(2026, 7, 5, 10, 0, 0, DateTimeKind.Utc), CancelledByUserId = (int?)5, CancellationReason = "Change of travel plans.", CreatedAt = new DateTime(2026, 7, 1, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 4, UserId = 5, TourScheduleId = 4, NumberOfPeople = 2, TotalAmount = 90.00m, StatusId = 2, StatusChangedAt = new DateTime(2026, 7, 14, 8, 0, 0, DateTimeKind.Utc), CreatedAt = new DateTime(2026, 7, 14, 8, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedPayments(ModelBuilder modelBuilder)
        {
            // 10% platform fee snapshotted per payment. Booking 3 was paid then fully refunded (Refunded).
            modelBuilder.Entity<Payment>().HasData(
                new { Id = 1, BookingId = 1, StripePaymentIntentId = "pi_seed_0001", Amount = 50.00m, Currency = "bam", PlatformFeePercentage = 10.00m, PlatformFeeAmount = 5.00m, Status = PaymentStatus.Succeeded, SucceededAt = (DateTime?)new DateTime(2026, 6, 15, 9, 1, 0, DateTimeKind.Utc), CreatedAt = new DateTime(2026, 6, 15, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 2, BookingId = 2, StripePaymentIntentId = "pi_seed_0002", Amount = 30.00m, Currency = "bam", PlatformFeePercentage = 10.00m, PlatformFeeAmount = 3.00m, Status = PaymentStatus.Succeeded, SucceededAt = (DateTime?)new DateTime(2026, 7, 9, 15, 1, 0, DateTimeKind.Utc), CreatedAt = new DateTime(2026, 7, 9, 15, 0, 0, DateTimeKind.Utc) },
                new { Id = 3, BookingId = 3, StripePaymentIntentId = "pi_seed_0003", Amount = 120.00m, Currency = "bam", PlatformFeePercentage = 10.00m, PlatformFeeAmount = 12.00m, Status = PaymentStatus.Refunded, SucceededAt = (DateTime?)new DateTime(2026, 7, 1, 12, 1, 0, DateTimeKind.Utc), CreatedAt = new DateTime(2026, 7, 1, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 4, BookingId = 4, StripePaymentIntentId = "pi_seed_0004", Amount = 90.00m, Currency = "bam", PlatformFeePercentage = 10.00m, PlatformFeeAmount = 9.00m, Status = PaymentStatus.Succeeded, SucceededAt = (DateTime?)new DateTime(2026, 7, 14, 8, 1, 0, DateTimeKind.Utc), CreatedAt = new DateTime(2026, 7, 14, 8, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedRefunds(ModelBuilder modelBuilder)
        {
            // Booking 3 cancelled well over 72h before start → 100% tier applied on the charged amount.
            modelBuilder.Entity<Refund>().HasData(
                new { Id = 1, PaymentId = 3, StripeRefundId = "re_seed_0001", Amount = 120.00m, PercentageApplied = 100, Reason = "User cancellation more than 72 hours before start.", InitiatedByUserId = 5, CreatedAt = new DateTime(2026, 7, 5, 10, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedDestinationReviews(ModelBuilder modelBuilder)
        {
            // Open to registered users. Drives the denormalized AverageRating on destinations 1/2/7/11.
            modelBuilder.Entity<DestinationReview>().HasData(
                new { Id = 1, DestinationId = 1, UserId = 5, Rating = 5, Comment = "Breathtaking bridge — a must-see, especially at sunset.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 21, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 2, DestinationId = 1, UserId = 4, Rating = 4, Comment = "Beautiful, but very crowded in summer.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 22, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 3, DestinationId = 7, UserId = 5, Rating = 5, Comment = "A magical, peaceful place right by the river source.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 23, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 4, DestinationId = 11, UserId = 4, Rating = 4, Comment = "Great atmosphere, coppersmiths and the best coffee.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 24, 9, 0, 0, DateTimeKind.Utc) },
                new { Id = 5, DestinationId = 2, UserId = 4, Rating = 5, Comment = "Amazing waterfalls, perfect for a hot summer day.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 25, 9, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedTourReviews(ModelBuilder modelBuilder)
        {
            // Gated to a Completed booking: user 5's completed booking 1 on tour 1.
            modelBuilder.Entity<TourReview>().HasData(
                new { Id = 1, TourId = 1, BookingId = 1, UserId = 5, Rating = 5, Comment = "Fantastic guide and a perfect route across the old town.", IsRemoved = false, CreatedAt = new DateTime(2026, 6, 21, 10, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedFavorites(ModelBuilder modelBuilder)
        {
            // Exactly one target per row (check constraint): destinations for 1–3, a tour for the last.
            modelBuilder.Entity<Favorite>().HasData(
                new { Id = 1, UserId = 4, DestinationId = (int?)1, TourId = (int?)null, CreatedAt = SeedDate },
                new { Id = 2, UserId = 4, DestinationId = (int?)7, TourId = (int?)null, CreatedAt = SeedDate },
                new { Id = 3, UserId = 5, DestinationId = (int?)2, TourId = (int?)null, CreatedAt = SeedDate },
                new { Id = 4, UserId = 4, DestinationId = (int?)null, TourId = (int?)3, CreatedAt = SeedDate }
            );
        }

        private void SeedUserInteractions(ModelBuilder modelBuilder)
        {
            // Rich, explained history for user 4 (onboarding + views + searches + favorites) so first-run
            // recommendations are non-trivial; plus completion/high-review signals for user 5. Weights
            // match docs/context/04-recommender-spec.md §2.
            modelBuilder.Entity<UserInteraction>().HasData(
                new { Id = 1, UserId = 4, InteractionType = InteractionType.OnboardingInterest, Weight = 2.0, CategoryId = (int?)2, CreatedAt = new DateTime(2026, 6, 1, 8, 0, 0, DateTimeKind.Utc) },
                new { Id = 2, UserId = 4, InteractionType = InteractionType.OnboardingInterest, Weight = 2.0, CategoryId = (int?)1, CreatedAt = new DateTime(2026, 6, 1, 8, 0, 0, DateTimeKind.Utc) },
                new { Id = 3, UserId = 4, InteractionType = InteractionType.OnboardingInterest, Weight = 2.0, TagId = (int?)2, CreatedAt = new DateTime(2026, 6, 1, 8, 0, 0, DateTimeKind.Utc) },
                new { Id = 4, UserId = 4, InteractionType = InteractionType.View, Weight = 1.0, DestinationId = (int?)1, CreatedAt = new DateTime(2026, 6, 5, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 5, UserId = 4, InteractionType = InteractionType.View, Weight = 1.0, DestinationId = (int?)2, CreatedAt = new DateTime(2026, 6, 6, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 6, UserId = 4, InteractionType = InteractionType.View, Weight = 1.0, DestinationId = (int?)9, CreatedAt = new DateTime(2026, 6, 7, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 7, UserId = 4, InteractionType = InteractionType.Search, Weight = 1.0, SearchTerm = "waterfall", TagId = (int?)2, CreatedAt = new DateTime(2026, 6, 8, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 8, UserId = 4, InteractionType = InteractionType.Search, Weight = 1.0, SearchTerm = "old town", CategoryId = (int?)7, CreatedAt = new DateTime(2026, 6, 9, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 9, UserId = 4, InteractionType = InteractionType.Favorite, Weight = 3.0, DestinationId = (int?)1, CreatedAt = new DateTime(2026, 6, 10, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 10, UserId = 4, InteractionType = InteractionType.Favorite, Weight = 3.0, DestinationId = (int?)7, CreatedAt = new DateTime(2026, 6, 11, 12, 0, 0, DateTimeKind.Utc) },
                new { Id = 11, UserId = 5, InteractionType = InteractionType.BookingCompleted, Weight = 5.0, DestinationId = (int?)1, CreatedAt = new DateTime(2026, 6, 20, 13, 0, 0, DateTimeKind.Utc) },
                new { Id = 12, UserId = 5, InteractionType = InteractionType.ReviewHigh, Weight = 3.0, DestinationId = (int?)1, CreatedAt = new DateTime(2026, 6, 21, 9, 30, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedRoleApplications(ModelBuilder modelBuilder)
        {
            // One pending Curator application so the admin moderation screen is non-empty.
            modelBuilder.Entity<RoleApplication>().HasData(
                new { Id = 1, UserId = 5, RoleId = 3, Motivation = "I am a local historian and want to contribute and maintain destinations from the Una-Sana region.", RegionId = (int?)3, Status = RoleApplicationStatus.Pending, CreatedAt = new DateTime(2026, 7, 12, 9, 0, 0, DateTimeKind.Utc) }
            );
        }

        private void SeedNotifications(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Notification>().HasData(
                new { Id = 1, UserId = 5, Title = "Booking confirmed", Text = "Your booking for 'Mostar Old Town Walking Tour' has been confirmed.", Type = NotificationType.BookingConfirmed, IsRead = true, ReadAt = (DateTime?)new DateTime(2026, 6, 16, 8, 0, 0, DateTimeKind.Utc), RelatedEntityId = (int?)1, CreatedAt = new DateTime(2026, 6, 15, 9, 5, 0, DateTimeKind.Utc) },
                new { Id = 2, UserId = 5, Title = "Tour completed", Text = "Your tour is completed. Share your experience by leaving a review!", Type = NotificationType.BookingCompleted, IsRead = false, RelatedEntityId = (int?)1, CreatedAt = new DateTime(2026, 6, 20, 13, 0, 0, DateTimeKind.Utc) },
                new { Id = 3, UserId = 4, Title = "Booking confirmed", Text = "Your booking for 'Sarajevo Cultural Heritage Tour' has been confirmed.", Type = NotificationType.BookingConfirmed, IsRead = false, RelatedEntityId = (int?)2, CreatedAt = new DateTime(2026, 7, 10, 11, 5, 0, DateTimeKind.Utc) },
                new { Id = 4, UserId = 5, Title = "Refund issued", Text = "A refund of 120.00 KM has been issued for your cancelled booking.", Type = NotificationType.RefundIssued, IsRead = false, RelatedEntityId = (int?)3, CreatedAt = new DateTime(2026, 7, 5, 10, 5, 0, DateTimeKind.Utc) }
            );
        }
    }
}
