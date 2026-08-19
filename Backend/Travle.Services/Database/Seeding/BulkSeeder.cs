using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using NodaTime;
using Travle.Model.Constants;

namespace Travle.Services.Database.Seeding
{
    /// <summary>
    /// Idempotent, additive runtime seeder that turns the small demo baseline into a rich, realistic
    /// dataset: the full geographic + classification reference set, ~35 extra users (with outlier
    /// curators/organizers for the statistics), the city-by-city destination catalogue, hundreds of tours
    /// with past and future schedules, and a large body of bookings/payments/refunds concentrated around
    /// "now" — plus thousands of reviews, favourites, recommender interactions, notifications and role
    /// applications. It is the sanctioned "rich data → runtime seeder" path (02 §4): it touches no HasData
    /// and needs no migration, lets the database assign every id, computes all dates relative to
    /// <see cref="DateTime.UtcNow"/>, and is guarded so a re-run on an already-seeded database is a no-op.
    /// Everything runs inside one transaction, so a partial failure rolls back cleanly.
    /// </summary>
    public static class BulkSeeder
    {
        private const decimal FeePercentage = 10m;
        private const string IntentPrefix = "pi_seed_bulk_";
        private const string RefundPrefix = "re_seed_bulk_";

        // Password "test", produced with the exact CryptoService PBKDF2 parameters — identical hash format to
        // runtime-created accounts (course §E), so every seeded user logs in with "test".
        private const string TestPasswordHash = "2FRMSidG5N9i/hqW9AXpRDLhOJq5DBQlRdE7MGBsaLU=";
        private const string TestPasswordSalt = "d38hQJKnSdlVdlDAUMRJAA==";

        private sealed record RefMaps(
            Dictionary<string, int> City,
            Dictionary<string, int> Category,
            Dictionary<string, int> Tag,
            Dictionary<string, int> TourType);

        private sealed record UserPools(
            IReadOnlyList<int> Curators,
            IReadOnlyList<int> OutlierCurators,
            IReadOnlyList<int> Organizers,
            IReadOnlyList<int> OutlierOrganizers,
            IReadOnlyList<int> Travelers);

        private sealed record DestInfo(
            int Id, int CityId, string CityName, string Name, string CategoryName,
            int SubmittedByUserId, DestinationStatus Status);

        private sealed class Slot
        {
            public required TourSchedule Schedule { get; init; }
            public required int OrganizerId { get; init; }
            public required decimal Price { get; init; }
            public required int PrimaryDestinationId { get; init; }
        }

        private sealed record CompletedBooking(int BookingId, int TourId, int UserId, int PrimaryDestinationId);

        public static async Task SeedAsync(TravleDbContext db, ILogger logger, CancellationToken ct = default)
        {
            if (await db.Destinations.CountAsync(ct) > 50)
            {
                return; // already bulk-seeded
            }

            var rng = new Random(230172);
            logger.LogInformation("Bulk seed starting…");

            await using var tx = await db.Database.BeginTransactionAsync(ct);

            await SeedCoreReferenceAsync(db, ct);
            var maps = await SeedReferenceAsync(db, ct);
            var users = await SeedUsersAsync(db, rng, maps, ct);
            var dests = await SeedDestinationsAsync(db, rng, maps, users, ct);
            var slots = await SeedToursAsync(db, rng, maps, users, dests, ct);
            var completed = await SeedBookingsAsync(db, rng, users, slots, ct);
            var highReviews = await SeedReviewsAsync(db, rng, users, dests, completed, ct);
            await SeedEngagementAsync(db, rng, maps, users, dests, slots, completed, highReviews, ct);

            await tx.CommitAsync(ct);

            logger.LogInformation(
                "Bulk seed complete: {Cities} cities, {Dest} destinations, {Tours} tours, {Sched} schedules, {Book} bookings.",
                await db.Cities.CountAsync(ct), await db.Destinations.CountAsync(ct),
                await db.Tours.CountAsync(ct), await db.TourSchedules.CountAsync(ct),
                await db.Bookings.CountAsync(ct));
        }

        // ---------------------------------------------------------------- Core reference (roles, statuses, tiers)

        private static async Task SeedCoreReferenceAsync(TravleDbContext db, CancellationToken ct)
        {
            // Roles — names are load-bearing (JWT claims + authorization policies); inserting in this order
            // gives ids 1-4, mirroring the original seed.
            db.Roles.AddRange(
                new Role { Name = RoleNames.Admin, Description = "Full administrative access." },
                new Role { Name = RoleNames.Traveler, Description = "Browses destinations and books tours." },
                new Role { Name = RoleNames.Curator, Description = "Submits and curates tourist destinations." },
                new Role { Name = RoleNames.Organizer, Description = "Creates and manages tours and schedules." });

            // Booking statuses — the ids are a HARD contract: they must equal BookingStatusCode, because the
            // filtered unique index on Bookings references StatusId IN (1,2,3) and the state machine matches on
            // these. On a fresh table, inserting the six in enum order yields ids 1-6; asserted below so any
            // surprise (a non-empty database) fails loudly instead of corrupting the contract.
            var statuses = Enum.GetValues<BookingStatusCode>()
                .OrderBy(code => (int)code)
                .Select(code => new BookingStatus { Name = code.ToString() })
                .ToList();
            db.BookingStatuses.AddRange(statuses);

            // Global refund ladder (03 §refunds). HoursBeforeMax null = unbounded.
            db.RefundPolicyTiers.AddRange(
                new RefundPolicyTier { HoursBeforeMin = 72, HoursBeforeMax = null, Percentage = 100 },
                new RefundPolicyTier { HoursBeforeMin = 24, HoursBeforeMax = 72, Percentage = 50 },
                new RefundPolicyTier { HoursBeforeMin = 1, HoursBeforeMax = 24, Percentage = 25 },
                new RefundPolicyTier { HoursBeforeMin = 0, HoursBeforeMax = 1, Percentage = 0 });

            await db.SaveChangesAsync(ct);

            foreach (var status in statuses)
            {
                var expected = (int)Enum.Parse<BookingStatusCode>(status.Name);
                if (status.Id != expected)
                {
                    throw new InvalidOperationException(
                        $"Seed invariant broken: BookingStatus '{status.Name}' got id {status.Id}, expected {expected}. "
                        + "The database must be empty before the bulk seed runs.");
                }
            }

            db.ChangeTracker.Clear();
        }

        // ---------------------------------------------------------------- Reference data

        private static async Task<RefMaps> SeedReferenceAsync(TravleDbContext db, CancellationToken ct)
        {
            // Countries.
            var countryByName = await db.Countries.ToDictionaryAsync(c => c.Name, ct);
            foreach (var cs in SeedGeography.Countries)
            {
                if (!countryByName.ContainsKey(cs.Name))
                {
                    var country = new Country { Name = cs.Name };
                    db.Countries.Add(country);
                    countryByName[cs.Name] = country;
                }
            }
            await db.SaveChangesAsync(ct);

            // Regions.
            var regionByKey = (await db.Regions.ToListAsync(ct)).ToDictionary(r => (r.CountryId, r.Name));
            foreach (var cs in SeedGeography.Countries)
            {
                var countryId = countryByName[cs.Name].Id;
                foreach (var rs in cs.Regions)
                {
                    var key = (countryId, rs.Name);
                    if (!regionByKey.ContainsKey(key))
                    {
                        var region = new Region { CountryId = countryId, Name = rs.Name };
                        db.Regions.Add(region);
                        regionByKey[key] = region;
                    }
                }
            }
            await db.SaveChangesAsync(ct);

            // Cities: create missing, re-home existing into the correct region (the city lists are the source
            // of truth for region membership).
            var cityByKey = new Dictionary<(int, string), City>();
            foreach (var city in await db.Cities.Include(c => c.Region).ToListAsync(ct))
            {
                cityByKey[(city.Region.CountryId, city.Name)] = city;
            }
            foreach (var cs in SeedGeography.Countries)
            {
                var countryId = countryByName[cs.Name].Id;
                foreach (var rs in cs.Regions)
                {
                    var regionId = regionByKey[(countryId, rs.Name)].Id;
                    foreach (var cityName in rs.Cities)
                    {
                        var key = (countryId, cityName);
                        if (cityByKey.TryGetValue(key, out var existing))
                        {
                            if (existing.RegionId != regionId)
                            {
                                existing.RegionId = regionId;
                            }
                        }
                        else
                        {
                            var city = new City { RegionId = regionId, Name = cityName };
                            db.Cities.Add(city);
                            cityByKey[key] = city;
                        }
                    }
                }
            }
            await db.SaveChangesAsync(ct);

            // Name → id lookups. Cities are keyed by name only (adequate for the BiH-centric destinations);
            // ordering by CountryId lets Bosnia/Croatia win any cross-country name clash.
            var cityRows = await db.Cities.Select(c => new { c.Id, c.Name, c.Region.CountryId }).ToListAsync(ct);
            var cityMap = new Dictionary<string, int>();
            foreach (var c in cityRows.OrderBy(c => c.CountryId))
            {
                cityMap.TryAdd(c.Name, c.Id);
            }

            var categoryMap = await UpsertByNameAsync(db, db.DestinationCategories, SeedTaxonomy.Categories, e => e.Name, (e, n) => e.Name = n, ct);
            var tagMap = await UpsertByNameAsync(db, db.Tags, SeedTaxonomy.Tags, e => e.Name, (e, n) => e.Name = n, ct);
            var tourTypeMap = await UpsertByNameAsync(db, db.TourTypes, SeedTaxonomy.TourTypes, e => e.Name, (e, n) => e.Name = n, ct);

            db.ChangeTracker.Clear();
            return new RefMaps(cityMap, categoryMap, tagMap, tourTypeMap);
        }

        // Generic name-based upsert for the simple classification tables. Name is read/written through
        // delegates so no shared interface has to be added to the entities.
        private static async Task<Dictionary<string, int>> UpsertByNameAsync<T>(
            TravleDbContext db, DbSet<T> set, string[] names,
            Func<T, string> getName, Action<T, string> setName, CancellationToken ct)
            where T : BaseEntity, new()
        {
            var byName = (await set.ToListAsync(ct)).ToDictionary(getName);
            foreach (var name in names)
            {
                if (!byName.ContainsKey(name))
                {
                    var entity = new T();
                    setName(entity, name);
                    set.Add(entity);
                    byName[name] = entity;
                }
            }
            await db.SaveChangesAsync(ct);
            return byName.ToDictionary(kv => kv.Key, kv => kv.Value.Id);
        }

        // ---------------------------------------------------------------- Users

        private static async Task<UserPools> SeedUsersAsync(TravleDbContext db, Random rng, RefMaps maps, CancellationToken ct)
        {
            var roleByName = await db.Roles.ToDictionaryAsync(r => r.Name, ct);
            var existingUsernames = (await db.Users.Select(u => u.Username).ToListAsync(ct)).ToHashSet();

            // The fixed graded demo logins first (stable usernames; "curator" is multi-role). Password "test".
            foreach (var core in SeedText.CoreUsers)
            {
                if (existingUsernames.Contains(core.Username))
                {
                    continue;
                }

                var coreUser = new User
                {
                    FirstName = core.FirstName,
                    LastName = core.LastName,
                    Email = core.Email,
                    Username = core.Username,
                    PasswordHash = TestPasswordHash,
                    PasswordSalt = TestPasswordSalt,
                    IsSuspended = false,
                    IsOnboarded = core.IsOnboarded,
                    OnboardingPromptCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-rng.Next(200, 730)),
                };
                foreach (var roleName in core.Roles)
                {
                    coreUser.UserRoles.Add(new UserRole { RoleId = roleByName[roleName].Id });
                }
                db.Users.Add(coreUser);
            }

            foreach (var seed in SeedText.Users)
            {
                if (existingUsernames.Contains(seed.Username))
                {
                    continue;
                }

                var user = new User
                {
                    FirstName = seed.FirstName,
                    LastName = seed.LastName,
                    Email = seed.Email,
                    Username = seed.Username,
                    PasswordHash = TestPasswordHash,
                    PasswordSalt = TestPasswordSalt,
                    IsSuspended = false,
                    IsOnboarded = seed.Role == SeedText.Traveler,
                    OnboardingPromptCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-rng.Next(30, 730)),
                };

                if (seed.Role == SeedText.Traveler)
                {
                    var home = SeedText.TravelerHomeCities[rng.Next(SeedText.TravelerHomeCities.Length)];
                    if (maps.City.TryGetValue(home, out var cityId))
                    {
                        user.CityId = cityId;
                    }
                }

                user.UserRoles.Add(new UserRole { RoleId = roleByName[seed.Role].Id });
                db.Users.Add(user);
            }
            await db.SaveChangesAsync(ct);

            var all = await db.Users.Include(u => u.UserRoles).ThenInclude(ur => ur.Role).ToListAsync(ct);
            var idByUsername = all.ToDictionary(u => u.Username, u => u.Id);

            List<int> curators = [], organizers = [], travelers = [];
            foreach (var u in all)
            {
                var roles = u.UserRoles.Select(ur => ur.Role.Name).ToHashSet();
                if (roles.Contains(RoleNames.Curator)) curators.Add(u.Id);
                if (roles.Contains(RoleNames.Organizer)) organizers.Add(u.Id);
                if (roles.Contains(RoleNames.Traveler)) travelers.Add(u.Id);
            }

            List<int> IdsOf(string role) => SeedText.Users
                .Where(x => x.Outlier && x.Role == role && idByUsername.ContainsKey(x.Username))
                .Select(x => idByUsername[x.Username]).ToList();

            db.ChangeTracker.Clear();
            return new UserPools(curators, IdsOf(SeedText.Curator), organizers, IdsOf(SeedText.Organizer), travelers);
        }

        // ---------------------------------------------------------------- Destinations

        private static async Task<List<DestInfo>> SeedDestinationsAsync(
            TravleDbContext db, Random rng, RefMaps maps, UserPools users, CancellationToken ct)
        {
            var existingNames = (await db.Destinations.Select(d => d.Name).ToListAsync(ct)).ToHashSet();
            var adminId = (await db.Users.Where(u => u.Username == "desktop").Select(u => u.Id).FirstAsync(ct));
            var regularCurators = users.Curators.Except(users.OutlierCurators).ToList();
            if (regularCurators.Count == 0) regularCurators = users.Curators.ToList();

            var created = new List<(Destination Entity, DestinationSeed Seed, int SubmittedBy, DestinationStatus Status)>();
            var index = 0;

            foreach (var seed in SeedDestinations.All)
            {
                if (existingNames.Contains(seed.Name)) continue;
                if (!maps.City.TryGetValue(seed.City, out var cityId)) continue;
                if (!maps.Category.TryGetValue(seed.Category, out var categoryId)) continue;

                index++;
                // Outliers author the majority (~55%) so they lead the statistics.
                var submittedBy = users.OutlierCurators.Count > 0 && rng.Next(100) < 55
                    ? Pick(rng, users.OutlierCurators)
                    : Pick(rng, regularCurators);

                var status = (index % 27) == 0 ? DestinationStatus.Pending
                           : (index % 53) == 0 ? DestinationStatus.Rejected
                           : DestinationStatus.Approved;

                var dest = new Destination
                {
                    Name = seed.Name,
                    Description = seed.Description,
                    CategoryId = categoryId,
                    CityId = cityId,
                    Latitude = seed.Lat,
                    Longitude = seed.Lng,
                    EntranceFee = seed.EntranceFee,
                    SubmittedByUserId = submittedBy,
                    Status = status,
                    IsFeatured = status == DestinationStatus.Approved && rng.Next(100) < 12,
                    AverageRating = 0,
                    ViewCount = rng.Next(15, 640),
                    CreatedAt = DateTime.UtcNow.AddDays(-rng.Next(20, 520)),
                };

                if (status != DestinationStatus.Pending)
                {
                    dest.ModeratedByUserId = adminId;
                    dest.ModeratedAt = dest.CreatedAt.AddDays(rng.Next(1, 6));
                    if (status == DestinationStatus.Rejected)
                    {
                        dest.RejectionReason = "Needs clearer photos and a more complete description before it can be published.";
                    }
                }

                foreach (var tagName in seed.Tags)
                {
                    if (maps.Tag.TryGetValue(tagName, out var tagId))
                    {
                        dest.DestinationTags.Add(new DestinationTag { TagId = tagId });
                    }
                }

                db.Destinations.Add(dest);
                created.Add((dest, seed, submittedBy, status));
            }

            await db.SaveChangesAsync(ct);

            var result = created
                .Select(c => new DestInfo(c.Entity.Id, c.Entity.CityId, c.Seed.City, c.Seed.Name,
                    c.Seed.Category, c.SubmittedBy, c.Status))
                .ToList();

            db.ChangeTracker.Clear();
            return result;
        }

        // ---------------------------------------------------------------- Tours + schedules

        private static async Task<List<Slot>> SeedToursAsync(
            TravleDbContext db, Random rng, RefMaps maps, UserPools users, List<DestInfo> dests, CancellationToken ct)
        {
            var approvedByCity = dests
                .Where(d => d.Status == DestinationStatus.Approved)
                .GroupBy(d => d.CityId)
                .ToDictionary(g => g.Key, g => g.ToList());

            var slots = new List<Slot>();
            var now = DateTime.UtcNow;

            void BuildTour(int organizerId, List<DestInfo> pool)
            {
                if (pool.Count == 0) return;

                var itinerary = TakeRandom(rng, pool, 1 + rng.Next(Math.Min(5, pool.Count)));
                var primary = itinerary[0];
                var typeName = Pick(rng, TourTypeCandidates(primary.CategoryName));
                var typeId = maps.TourType[typeName];

                var duration = 60 + rng.Next(0, 8) * 30;          // 60–270 min
                var price = 15m + rng.Next(0, 16) * 5m;           // 15–90 KM
                var capacity = 8 + rng.Next(0, 5) * 4;            // 8–24

                var tour = new Tour
                {
                    OrganizerId = organizerId,
                    Name = TourName(typeName, primary.CityName),
                    Description = $"A guided {typeName.ToLowerInvariant()} around {primary.CityName}, taking in "
                                  + $"{primary.Name}{(itinerary.Count > 1 ? " and more of the area's highlights" : "")}.",
                    DurationMinutes = duration,
                    PricePerPerson = price,
                    Capacity = capacity,
                    TourTypeId = typeId,
                    IsActive = rng.Next(100) < 92,
                    CreatedAt = now.AddDays(-rng.Next(20, 480)),
                };

                for (var i = 0; i < itinerary.Count; i++)
                {
                    tour.TourDestinations.Add(new TourDestination { DestinationId = itinerary[i].Id, SortOrder = i + 1, CreatedAt = tour.CreatedAt });
                }

                var scheduleCount = 2 + rng.Next(0, 4); // 2–5
                for (var s = 0; s < scheduleCount; s++)
                {
                    var offsetDays = ScheduleOffsetDays(rng);
                    // Generate a nice local departure hour (08:00–16:00) at the platform zone, then store the
                    // true UTC instant it represents — matching how the write path treats an organizer's pick,
                    // so the seeded slots display back at exactly these hours. See docs/time-and-timezones.md.
                    var startsAt = PlatformLocalToUtc(now.Date.AddDays(offsetDays).AddHours(8 + rng.Next(0, 9)));
                    var schedule = new TourSchedule
                    {
                        StartsAt = startsAt,
                        EndsAt = startsAt.AddMinutes(duration),
                        Capacity = capacity,
                        SeatsTaken = 0,
                        Status = ScheduleStatus.Active,
                        CreatedAt = tour.CreatedAt,
                    };
                    tour.Schedules.Add(schedule);
                    slots.Add(new Slot { Schedule = schedule, OrganizerId = organizerId, Price = price, PrimaryDestinationId = primary.Id });
                }

                db.Tours.Add(tour);
            }

            // At least one tour per city that has approved destinations; history-rich cities get two.
            foreach (var (_, pool) in approvedByCity)
            {
                var count = pool.Count >= 3 ? 1 + rng.Next(0, 2) : 1;
                for (var i = 0; i < count; i++)
                {
                    BuildTour(Pick(rng, users.Organizers), pool);
                }
            }

            // Outlier organizers get a large extra batch spanning random cities, so they dominate the charts.
            var cityPools = approvedByCity.Values.ToList();
            foreach (var organizerId in users.OutlierOrganizers)
            {
                var extra = 35 + rng.Next(0, 16);
                for (var i = 0; i < extra && cityPools.Count > 0; i++)
                {
                    BuildTour(organizerId, Pick(rng, cityPools));
                }
            }

            await db.SaveChangesAsync(ct);
            // NB: schedules stay tracked — the booking phase updates their SeatsTaken via these entities.
            return slots;
        }

        // ---------------------------------------------------------------- Bookings / payments / refunds

        private static async Task<List<CompletedBooking>> SeedBookingsAsync(
            TravleDbContext db, Random rng, UserPools users, List<Slot> slots, CancellationToken ct)
        {
            var now = DateTime.UtcNow;
            var travelers = users.Travelers;
            var pendingCompleted = new List<(Booking Booking, int TourId, int UserId, int PrimaryDest)>();

            var intentSeq = 1;
            var refundSeq = 1;
            string NextIntent() => $"{IntentPrefix}{intentSeq++:D6}";
            string NextRefund() => $"{RefundPrefix}{refundSeq++:D6}";

            foreach (var slot in slots)
            {
                var startsAt = slot.Schedule.StartsAt;
                var endsAt = slot.Schedule.EndsAt;
                var daysFromNow = Math.Abs((startsAt - now).TotalDays);

                var target = daysFromNow <= 30 ? rng.Next(2, 6)
                           : daysFromNow <= 90 ? rng.Next(1, 4)
                           : rng.Next(0, 3);
                if (target == 0) continue;

                foreach (var userId in TakeRandom(rng, travelers, Math.Min(target, travelers.Count)))
                {
                    var status = PickBookingStatus(rng, now, startsAt, endsAt);
                    var holds = status is BookingStatusCode.PaymentInProgress or BookingStatusCode.Pending
                        or BookingStatusCode.Confirmed or BookingStatusCode.Completed;

                    var remaining = slot.Schedule.Capacity - slot.Schedule.SeatsTaken;
                    if (holds && remaining <= 0) continue;

                    var wanted = 1 + rng.Next(0, 5);
                    var people = holds ? Math.Min(wanted, remaining) : Math.Min(wanted, slot.Schedule.Capacity);
                    if (people < 1) continue;

                    var amount = slot.Price * people;
                    var fee = RoundMoney(amount * FeePercentage / 100m);

                    var createdAt = endsAt < now ? startsAt.AddDays(-rng.Next(2, 26)) : now.AddDays(-rng.Next(0, 21));
                    if (createdAt > now) createdAt = now.AddDays(-rng.Next(0, 5));

                    var booking = new Booking
                    {
                        UserId = userId,
                        TourSchedule = slot.Schedule,
                        NumberOfPeople = people,
                        TotalAmount = amount,
                        StatusId = (int)status,
                        CreatedAt = createdAt,
                        StatusChangedAt = createdAt,
                    };

                    switch (status)
                    {
                        case BookingStatusCode.Completed:
                            booking.StatusChangedAt = endsAt.AddHours(1);
                            booking.ConfirmedByUserId = slot.OrganizerId;
                            booking.Payments.Add(SucceededPayment(NextIntent(), amount, fee, createdAt));
                            break;

                        case BookingStatusCode.Confirmed:
                            booking.StatusChangedAt = createdAt.AddHours(rng.Next(1, 48));
                            booking.ConfirmedByUserId = slot.OrganizerId;
                            booking.Payments.Add(SucceededPayment(NextIntent(), amount, fee, createdAt));
                            break;

                        case BookingStatusCode.Pending:
                            booking.StatusChangedAt = createdAt.AddMinutes(rng.Next(5, 60));
                            booking.Payments.Add(SucceededPayment(NextIntent(), amount, fee, createdAt));
                            break;

                        case BookingStatusCode.PaymentInProgress:
                            booking.CreatedAt = now.AddMinutes(-rng.Next(1, 14));
                            booking.StatusChangedAt = booking.CreatedAt;
                            booking.ExpiresAt = booking.CreatedAt.AddMinutes(15);
                            break;

                        case BookingStatusCode.Expired:
                            booking.StatusChangedAt = createdAt.AddMinutes(15);
                            booking.ExpiresAt = booking.StatusChangedAt;
                            break;

                        case BookingStatusCode.Cancelled:
                            var upper = startsAt < now ? startsAt : now;
                            var spanHours = Math.Max(2.0, (upper - createdAt).TotalHours);
                            var cancelledAt = createdAt.AddHours(rng.NextDouble() * spanHours);
                            var pct = RefundPercentage((startsAt - cancelledAt).TotalHours);

                            booking.StatusChangedAt = cancelledAt;
                            booking.CancelledByUserId = userId;
                            booking.CancellationReason = Pick(rng, SeedText.CancellationReasons);

                            var payment = SucceededPayment(NextIntent(), amount, fee, createdAt);
                            if (pct > 0)
                            {
                                payment.Status = pct == 100 ? PaymentStatus.Refunded : PaymentStatus.PartiallyRefunded;
                                payment.Refunds.Add(new Refund
                                {
                                    StripeRefundId = NextRefund(),
                                    Amount = RoundMoney(amount * pct / 100m),
                                    PercentageApplied = pct,
                                    Reason = $"User cancellation ({pct}% tier).",
                                    InitiatedByUserId = userId,
                                    CreatedAt = cancelledAt.AddMinutes(2),
                                });
                            }
                            booking.Payments.Add(payment);
                            break;
                    }

                    if (holds)
                    {
                        slot.Schedule.SeatsTaken += people;
                    }

                    db.Bookings.Add(booking);

                    if (status == BookingStatusCode.Completed)
                    {
                        pendingCompleted.Add((booking, slot.Schedule.TourId, userId, slot.PrimaryDestinationId));
                    }
                }
            }

            await db.SaveChangesAsync(ct);

            var completed = pendingCompleted
                .Select(c => new CompletedBooking(c.Booking.Id, c.TourId, c.UserId, c.PrimaryDest))
                .ToList();

            db.ChangeTracker.Clear();
            return completed;
        }

        private static Payment SucceededPayment(string intentId, decimal amount, decimal fee, DateTime createdAt) => new()
        {
            StripePaymentIntentId = intentId,
            Amount = amount,
            Currency = "bam",
            PlatformFeePercentage = FeePercentage,
            PlatformFeeAmount = fee,
            Status = PaymentStatus.Succeeded,
            CreatedAt = createdAt.AddMinutes(3),
            SucceededAt = createdAt.AddMinutes(5),
        };

        // ---------------------------------------------------------------- Reviews

        private static async Task<List<(int UserId, int DestId)>> SeedReviewsAsync(
            TravleDbContext db, Random rng, UserPools users, List<DestInfo> dests,
            List<CompletedBooking> completed, CancellationToken ct)
        {
            var approved = dests.Where(d => d.Status == DestinationStatus.Approved).ToList();
            var travelers = users.Travelers;
            var now = DateTime.UtcNow;
            var adminId = await db.Users.Where(u => u.Username == "desktop").Select(u => u.Id).FirstAsync(ct);
            var highReviews = new List<(int, int)>();
            var ratingAgg = new Dictionary<int, (double Sum, int Count)>();

            foreach (var dest in approved)
            {
                // A genocide memorial and cemetery is a place of remembrance, not a tourist
                // attraction — it gets only respectful, reflective reviews, all highly rated and
                // never moderated off-topic (see SeedText.SrebrenicaMemorialReflections).
                var isMemorial = dest.Name.Contains(SeedText.SrebrenicaMemorialMatch, StringComparison.Ordinal);
                var reviewerCount = Math.Min(travelers.Count, 3 + rng.Next(0, 10));
                foreach (var userId in TakeRandom(rng, travelers, reviewerCount))
                {
                    int rating;
                    bool removed;
                    string comment;
                    if (isMemorial)
                    {
                        rating = rng.Next(100) < 70 ? 5 : 4;
                        removed = false;
                        comment = Pick(rng, SeedText.SrebrenicaMemorialReflections);
                    }
                    else
                    {
                        rating = WeightedRating(rng);
                        removed = rng.Next(100) < 4;
                        comment = rating >= 4 ? Pick(rng, SeedText.DestinationPraise)
                                : rating == 3 ? Pick(rng, SeedText.DestinationNeutral)
                                : Pick(rng, SeedText.DestinationCritical);
                    }

                    var review = new DestinationReview
                    {
                        DestinationId = dest.Id,
                        UserId = userId,
                        Rating = rating,
                        Comment = comment,
                        IsRemoved = removed,
                        CreatedAt = now.AddDays(-rng.Next(1, 400)),
                    };
                    if (removed)
                    {
                        review.RemovedByUserId = adminId;
                        review.RemovalReason = "Removed by moderation (off-topic).";
                    }
                    else
                    {
                        var agg = ratingAgg.GetValueOrDefault(dest.Id);
                        ratingAgg[dest.Id] = (agg.Sum + rating, agg.Count + 1);
                        if (rating >= 4) highReviews.Add((userId, dest.Id));
                    }

                    db.DestinationReviews.Add(review);
                }
            }
            await db.SaveChangesAsync(ct);

            // Denormalised AverageRating from the non-removed reviews.
            var ratedIds = ratingAgg.Keys.ToList();
            foreach (var d in await db.Destinations.Where(d => ratedIds.Contains(d.Id)).ToListAsync(ct))
            {
                var agg = ratingAgg[d.Id];
                d.AverageRating = agg.Count > 0 ? Math.Round(agg.Sum / agg.Count, 2) : 0;
            }
            await db.SaveChangesAsync(ct);

            // Tour reviews — gated to the reviewer's own Completed booking (unique per booking).
            foreach (var cb in completed)
            {
                if (rng.Next(100) >= 70) continue;
                var rating = WeightedRating(rng);
                var comment = rating >= 4 ? Pick(rng, SeedText.TourPraise)
                            : rating == 3 ? Pick(rng, SeedText.TourNeutral)
                            : Pick(rng, SeedText.TourCritical);
                db.TourReviews.Add(new TourReview
                {
                    TourId = cb.TourId,
                    BookingId = cb.BookingId,
                    UserId = cb.UserId,
                    Rating = rating,
                    Comment = comment,
                    IsRemoved = false,
                    CreatedAt = now.AddDays(-rng.Next(1, 200)),
                });
            }
            await db.SaveChangesAsync(ct);

            db.ChangeTracker.Clear();
            return highReviews;
        }

        // ---------------------------------------------------------------- Favourites / interactions / notifications / role apps

        private static async Task SeedEngagementAsync(
            TravleDbContext db, Random rng, RefMaps maps, UserPools users, List<DestInfo> dests,
            List<Slot> slots, List<CompletedBooking> completed, List<(int UserId, int DestId)> highReviews,
            CancellationToken ct)
        {
            var now = DateTime.UtcNow;
            var adminId = await db.Users.Where(u => u.Username == "desktop").Select(u => u.Id).FirstAsync(ct);
            var approvedDestIds = dests.Where(d => d.Status == DestinationStatus.Approved).Select(d => d.Id).ToList();
            var tourIds = slots.Select(s => s.Schedule.TourId).Distinct().ToList();
            var tourOrganizer = slots.GroupBy(s => s.Schedule.TourId).ToDictionary(g => g.Key, g => g.First().OrganizerId);
            var categoryIds = maps.Category.Values.ToList();
            var tagIds = maps.Tag.Values.ToList();

            var completedByUser = completed.GroupBy(c => c.UserId).ToDictionary(g => g.Key, g => g.ToList());
            var highByUser = highReviews.GroupBy(h => h.UserId).ToDictionary(g => g.Key, g => g.Select(h => h.DestId).Distinct().ToList());

            foreach (var userId in users.Travelers)
            {
                // Favourites (unique per user+target).
                var favDests = TakeRandom(rng, approvedDestIds, rng.Next(2, 7));
                foreach (var destId in favDests)
                {
                    db.Favorites.Add(new Favorite { UserId = userId, DestinationId = destId, CreatedAt = now.AddDays(-rng.Next(1, 200)) });
                }
                foreach (var tourId in TakeRandom(rng, tourIds, rng.Next(1, 4)))
                {
                    db.Favorites.Add(new Favorite { UserId = userId, TourId = tourId, CreatedAt = now.AddDays(-rng.Next(1, 200)) });
                }

                // Recommender interactions (append-only diary).
                foreach (var _ in Enumerable.Range(0, 2 + rng.Next(0, 2)))
                {
                    var onCategory = rng.Next(2) == 0;
                    db.UserInteractions.Add(new UserInteraction
                    {
                        UserId = userId,
                        InteractionType = InteractionType.OnboardingInterest,
                        Weight = 2.0,
                        CategoryId = onCategory ? Pick(rng, categoryIds) : null,
                        TagId = onCategory ? null : Pick(rng, tagIds),
                        CreatedAt = now.AddDays(-rng.Next(30, 400)),
                    });
                }
                foreach (var destId in favDests)
                {
                    db.UserInteractions.Add(new UserInteraction { UserId = userId, InteractionType = InteractionType.Favorite, Weight = 3.0, DestinationId = destId, CreatedAt = now.AddDays(-rng.Next(1, 180)) });
                }
                foreach (var destId in TakeRandom(rng, approvedDestIds, 3 + rng.Next(0, 4)))
                {
                    db.UserInteractions.Add(new UserInteraction { UserId = userId, InteractionType = InteractionType.View, Weight = 1.0, DestinationId = destId, CreatedAt = now.AddDays(-rng.Next(1, 300)) });
                }
                foreach (var _ in Enumerable.Range(0, 1 + rng.Next(0, 2)))
                {
                    db.UserInteractions.Add(new UserInteraction { UserId = userId, InteractionType = InteractionType.Search, Weight = 1.0, SearchTerm = Pick(rng, SeedText.SearchTerms), CategoryId = Pick(rng, categoryIds), CreatedAt = now.AddDays(-rng.Next(1, 250)) });
                }
                foreach (var cb in completedByUser.GetValueOrDefault(userId, []).Take(5))
                {
                    db.UserInteractions.Add(new UserInteraction { UserId = userId, InteractionType = InteractionType.BookingCompleted, Weight = 5.0, DestinationId = cb.PrimaryDestinationId, CreatedAt = now.AddDays(-rng.Next(1, 200)) });
                }
                foreach (var destId in highByUser.GetValueOrDefault(userId, []).Take(5))
                {
                    db.UserInteractions.Add(new UserInteraction { UserId = userId, InteractionType = InteractionType.ReviewHigh, Weight = 3.0, DestinationId = destId, CreatedAt = now.AddDays(-rng.Next(1, 180)) });
                }

                // A couple of activity notifications per traveller.
                foreach (var cb in completedByUser.GetValueOrDefault(userId, []).Take(2))
                {
                    db.Notifications.Add(new Notification
                    {
                        UserId = userId,
                        Title = "Tour completed",
                        Text = "Your tour is completed. Share your experience by leaving a review!",
                        Type = NotificationType.BookingCompleted,
                        IsRead = rng.Next(2) == 0,
                        RelatedEntityId = cb.BookingId,
                        CreatedAt = now.AddDays(-rng.Next(1, 120)),
                    });
                }
            }

            // Curator notifications: some of their approved destinations were approved.
            foreach (var group in dests.Where(d => d.Status == DestinationStatus.Approved).GroupBy(d => d.SubmittedByUserId))
            {
                foreach (var dest in TakeRandom(rng, group.ToList(), Math.Min(3, group.Count())))
                {
                    db.Notifications.Add(new Notification
                    {
                        UserId = group.Key,
                        Title = "Destination approved",
                        Text = $"Your destination '{dest.Name}' has been approved and is now public.",
                        Type = NotificationType.DestinationApproved,
                        IsRead = rng.Next(2) == 0,
                        RelatedEntityId = dest.Id,
                        CreatedAt = now.AddDays(-rng.Next(1, 200)),
                    });
                }
            }

            // Organizer notifications: a sample of bookings placed on their tours.
            foreach (var cb in completed.Where(_ => rng.Next(100) < 25))
            {
                if (!tourOrganizer.TryGetValue(cb.TourId, out var organizerId)) continue;
                db.Notifications.Add(new Notification
                {
                    UserId = organizerId,
                    Title = "New booking",
                    Text = "A traveler booked one of your tours.",
                    Type = NotificationType.BookingPlaced,
                    IsRead = rng.Next(2) == 0,
                    RelatedEntityId = cb.BookingId,
                    CreatedAt = now.AddDays(-rng.Next(1, 120)),
                });
            }

            // A few role applications so the moderation queue and history are populated.
            var applicants = TakeRandom(rng, users.Travelers, Math.Min(9, users.Travelers.Count));
            var roleByName = await db.Roles.ToDictionaryAsync(r => r.Name, ct);
            for (var i = 0; i < applicants.Count; i++)
            {
                var wantsCurator = rng.Next(2) == 0;
                var roleId = roleByName[wantsCurator ? RoleNames.Curator : RoleNames.Organizer].Id;
                var motivation = Pick(rng, wantsCurator ? SeedText.CuratorMotivations : SeedText.OrganizerMotivations);

                var app = new RoleApplication
                {
                    UserId = applicants[i],
                    RoleId = roleId,
                    Motivation = motivation,
                    Status = RoleApplicationStatus.Pending,
                    CreatedAt = now.AddDays(-rng.Next(1, 120)),
                };
                if (i % 3 == 1)
                {
                    app.Status = RoleApplicationStatus.Approved;
                    app.DecidedByUserId = adminId;
                    app.DecidedAt = app.CreatedAt.AddDays(rng.Next(1, 5));
                }
                else if (i % 3 == 2)
                {
                    app.Status = RoleApplicationStatus.Rejected;
                    app.DecidedByUserId = adminId;
                    app.DecidedAt = app.CreatedAt.AddDays(rng.Next(1, 5));
                    app.RejectionReason = "Please add more detail about your local experience and re-apply.";
                }
                db.RoleApplications.Add(app);
            }

            await db.SaveChangesAsync(ct);
            db.ChangeTracker.Clear();
        }

        // ---------------------------------------------------------------- Helpers

        private static T Pick<T>(Random rng, IReadOnlyList<T> list) => list[rng.Next(list.Count)];

        private static List<T> TakeRandom<T>(Random rng, IReadOnlyList<T> source, int count)
        {
            var pool = source.ToList();
            var take = Math.Min(count, pool.Count);
            for (var i = 0; i < take; i++)
            {
                var j = rng.Next(i, pool.Count);
                (pool[i], pool[j]) = (pool[j], pool[i]);
            }
            return pool.GetRange(0, take);
        }

        private static decimal RoundMoney(decimal value) => Math.Round(value, 2, MidpointRounding.AwayFromZero);

        private static int RefundPercentage(double hoursBeforeStart) =>
            hoursBeforeStart > 72 ? 100 : hoursBeforeStart >= 24 ? 50 : hoursBeforeStart >= 1 ? 25 : 0;

        private static int WeightedRating(Random rng)
        {
            var roll = rng.Next(100);
            return roll < 45 ? 5 : roll < 75 ? 4 : roll < 90 ? 3 : roll < 96 ? 2 : 1;
        }

        // Interprets a naive wall-clock as local to the platform zone and returns the UTC instant it
        // represents (DST-aware, via NodaTime's bundled tzdb). Lenient so a generated hour that happens to
        // land on a DST transition never throws; the seed's 08:00–16:00 range never hits a transition
        // anyway. All seeded cities are in the platform zone, so this matches the runtime write path.
        private static DateTime PlatformLocalToUtc(DateTime naiveLocal)
        {
            var zone = DateTimeZoneProviders.Tzdb[TimeDefaults.PlatformTimeZoneId];
            var local = LocalDateTime.FromDateTime(DateTime.SpecifyKind(naiveLocal, DateTimeKind.Unspecified));
            return local.InZoneLeniently(zone).ToDateTimeUtc();
        }

        // Schedule dates cluster near "now": ~60% within a month, then a month-to-quarter band, then the tails.
        private static int ScheduleOffsetDays(Random rng)
        {
            var band = rng.Next(100);
            return band < 60 ? rng.Next(-30, 31)
                 : band < 85 ? (rng.Next(2) == 0 ? rng.Next(-90, -30) : rng.Next(31, 61))
                 : (rng.Next(2) == 0 ? rng.Next(-180, -90) : rng.Next(61, 91));
        }

        private static BookingStatusCode PickBookingStatus(Random rng, DateTime now, DateTime startsAt, DateTime endsAt)
        {
            if (endsAt < now)
            {
                return Weighted(rng, (BookingStatusCode.Completed, 80), (BookingStatusCode.Cancelled, 15), (BookingStatusCode.Expired, 5));
            }
            if (startsAt <= now.AddDays(30))
            {
                return Weighted(rng,
                    (BookingStatusCode.Confirmed, 45), (BookingStatusCode.Pending, 30),
                    (BookingStatusCode.Cancelled, 8), (BookingStatusCode.Expired, 9), (BookingStatusCode.PaymentInProgress, 8));
            }
            return Weighted(rng,
                (BookingStatusCode.Pending, 45), (BookingStatusCode.Confirmed, 40),
                (BookingStatusCode.PaymentInProgress, 10), (BookingStatusCode.Cancelled, 5));
        }

        private static T Weighted<T>(Random rng, params (T Value, int Weight)[] options)
        {
            var total = options.Sum(o => o.Weight);
            var roll = rng.Next(total);
            var acc = 0;
            foreach (var (value, weight) in options)
            {
                acc += weight;
                if (roll < acc) return value;
            }
            return options[^1].Value;
        }

        private static string[] TourTypeCandidates(string category) => category switch
        {
            "Waterfall" or "River & Spring" or "Canyon" or "Lake"
                => ["Rafting & Water Tour", "Nature & Hiking Tour", "Photography Tour", "Adventure Tour"],
            "National Park" or "Mountain & Peak" or "Natural Wonder" or "Adventure" or "Cave"
                => ["Nature & Hiking Tour", "Adventure Tour", "Photography Tour"],
            "Religious Site"
                => ["Religious & Pilgrimage Tour", "Cultural Tour"],
            "Fortress & Castle" or "Historical Site" or "Archaeological Site" or "Monument & Memorial" or "Bridge"
                => ["Historical Tour", "Cultural Tour", "Walking Tour"],
            "Old Town" or "Cultural Landmark"
                => ["City Sightseeing", "Walking Tour", "Food Tour", "Cultural Tour"],
            "Museum"
                => ["Cultural Tour", "City Sightseeing", "Walking Tour"],
            "Viewpoint" or "Park & Garden"
                => ["Walking Tour", "Photography Tour", "Nature & Hiking Tour"],
            _ => ["Walking Tour", "Cultural Tour"],
        };

        private static string TourName(string tourType, string city) => tourType switch
        {
            "Walking Tour" => $"{city} Old Town Walking Tour",
            "Cultural Tour" => $"{city} Cultural Heritage Tour",
            "Historical Tour" => $"{city} Historical Tour",
            "Adventure Tour" => $"{city} Adventure Day",
            "Food Tour" => $"{city} Food & Bazaar Walk",
            "Private Tour" => $"{city} Private Guided Tour",
            "Nature & Hiking Tour" => $"{city} Nature & Hiking Tour",
            "Photography Tour" => $"{city} Photography Tour",
            "Rafting & Water Tour" => $"{city} River & Rafting Adventure",
            "Religious & Pilgrimage Tour" => $"{city} Sacred Sites Tour",
            "City Sightseeing" => $"{city} Sightseeing Tour",
            "Multi-Day Tour" => $"{city} Region Multi-Day Tour",
            "Cycling Tour" => $"{city} Cycling Tour",
            "Wine & Gastronomy Tour" => $"{city} Wine & Gastronomy Tour",
            _ => $"{city} Guided Tour",
        };
    }
}
