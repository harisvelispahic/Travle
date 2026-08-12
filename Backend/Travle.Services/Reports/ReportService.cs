using Travle.Model.Constants;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Payments;
using Travle.Services.Reports.Documents;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using QuestPDF.Fluent;

namespace Travle.Services.Reports
{
    /// <summary>
    /// The reporting "read model". Owns every aggregate behind the admin dashboard, the two PDF reports
    /// and the organizer statistics screen. Aggregations run at the database (GroupBy / Sum / Count);
    /// only bounded, already-filtered result sets are ever folded in memory. No entity is mutated here.
    /// </summary>
    public sealed class ReportService : IReportService
    {
        private static readonly string[] MonthAbbreviations =
            ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

        // Bookings that represent genuine demand (paid or beyond) — used for popularity and per-tour counts.
        private static readonly int[] BookedStatusIds =
            [(int)BookingStatusCode.Pending, (int)BookingStatusCode.Confirmed, (int)BookingStatusCode.Completed];

        // Bookings that count on the activity chart: everything real, i.e. excluding never-paid holds
        // (PaymentInProgress) and expired holds. Cancelled bookings were still real demand at the time.
        private static readonly int[] ChartStatusIds =
        [
            (int)BookingStatusCode.Pending, (int)BookingStatusCode.Confirmed,
            (int)BookingStatusCode.Completed, (int)BookingStatusCode.Cancelled
        ];

        private const int TrailingMonths = 12;
        private const int RecentActivityCount = 8;
        private const int DefaultTopDestinations = 10;
        private const int MaxTopDestinations = 50;

        // Paging bounds for the curator destinations breakdown, matching the read base's clamp so the
        // list endpoint can never return an unbounded set.
        private const int DefaultPageSize = 10;
        private const int MaxPageSize = 100;

        private readonly TravleDbContext _dbContext;
        private readonly IAppAuthorizationService _authorization;
        private readonly PaymentOptions _paymentOptions;

        public ReportService(
            TravleDbContext dbContext,
            IAppAuthorizationService authorization,
            IOptions<PaymentOptions> paymentOptions)
        {
            _dbContext = dbContext;
            _authorization = authorization;
            _paymentOptions = paymentOptions.Value;
        }

        public async Task<DashboardResponse> GetDashboardAsync(CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var now = DateTime.UtcNow;
            var monthStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
            var monthEnd = monthStart.AddMonths(1);
            var windowStart = monthStart.AddMonths(-(TrailingMonths - 1));

            var totalUsers = await _dbContext.Users.CountAsync(cancellationToken);

            var activeTours = await _dbContext.Tours.CountAsync(
                t => t.IsActive
                     && !t.Organizer.IsSuspended
                     && t.Schedules.Any(s => s.Status == ScheduleStatus.Active && s.StartsAt > now),
                cancellationToken);

            var pendingRoleApplications = await _dbContext.RoleApplications.CountAsync(
                r => r.Status == RoleApplicationStatus.Pending, cancellationToken);

            var pendingDestinations = await _dbContext.Destinations.CountAsync(
                d => d.Status == DestinationStatus.Pending, cancellationToken);

            // Net revenue captured in the current calendar month: gross captured this month minus refunds
            // issued this month (each matched on its own creation instant), mirroring the payments screen.
            var grossThisMonth = await _dbContext.Payments
                .Where(p => (p.Status == PaymentStatus.Succeeded
                             || p.Status == PaymentStatus.Refunded
                             || p.Status == PaymentStatus.PartiallyRefunded)
                            && p.CreatedAt >= monthStart && p.CreatedAt < monthEnd)
                .SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0m;

            var refundedThisMonth = await _dbContext.Refunds
                .Where(r => r.CreatedAt >= monthStart && r.CreatedAt < monthEnd)
                .SumAsync(r => (decimal?)r.Amount, cancellationToken) ?? 0m;

            var bookingsPerMonth = await BuildBookingsPerMonthAsync(
                _dbContext.Bookings.Where(b => ChartStatusIds.Contains(b.StatusId)),
                windowStart, cancellationToken);

            var recentActivity = await BuildRecentActivityAsync(cancellationToken);

            return new DashboardResponse
            {
                TotalUsers = totalUsers,
                ActiveTours = activeTours,
                PendingRoleApplications = pendingRoleApplications,
                PendingDestinations = pendingDestinations,
                MonthlyNetRevenue = grossThisMonth - refundedThisMonth,
                Currency = _paymentOptions.Currency,
                BookingsPerMonth = bookingsPerMonth,
                RecentActivity = recentActivity
            };
        }

        public async Task<PopularDestinationsReport> GetPopularDestinationsAsync(
            PopularDestinationsReportSearch search, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var top = Math.Clamp(search.Top ?? DefaultTopDestinations, 1, MaxTopDestinations);

            var bookings = _dbContext.Bookings.AsNoTracking()
                .Where(b => BookedStatusIds.Contains(b.StatusId));
            if (search.FromDate is DateTime from)
            {
                bookings = bookings.Where(b => b.CreatedAt >= from);
            }
            if (search.ToDate is DateTime to)
            {
                bookings = bookings.Where(b => b.CreatedAt < to);
            }

            // Fan a booking out to every destination its tour visits (a multi-stop tour counts for each
            // stop), keep only approved destinations (optionally one category), then aggregate at the DB.
            var perDestination = await bookings
                .SelectMany(
                    b => b.TourSchedule.Tour.TourDestinations,
                    (b, td) => new { td.DestinationId, td.Destination.Status, td.Destination.CategoryId, b.NumberOfPeople })
                .Where(x => x.Status == DestinationStatus.Approved
                            && (search.CategoryId == null || x.CategoryId == search.CategoryId))
                .GroupBy(x => x.DestinationId)
                .Select(g => new { DestinationId = g.Key, Bookings = g.Count(), Travelers = g.Sum(x => x.NumberOfPeople) })
                .OrderByDescending(x => x.Bookings)
                .ThenByDescending(x => x.Travelers)
                .Take(top)
                .ToListAsync(cancellationToken);

            var ids = perDestination.Select(x => x.DestinationId).ToList();

            var metadata = await _dbContext.Destinations.AsNoTracking()
                .Where(d => ids.Contains(d.Id))
                .Select(d => new
                {
                    d.Id,
                    d.Name,
                    Category = d.Category.Name,
                    Region = d.City.Region.Name,
                    d.ViewCount
                })
                .ToListAsync(cancellationToken);
            var metadataById = metadata.ToDictionary(m => m.Id);

            var favoriteCounts = await _dbContext.Favorites.AsNoTracking()
                .Where(f => f.DestinationId != null && ids.Contains(f.DestinationId.Value))
                .GroupBy(f => f.DestinationId!.Value)
                .Select(g => new { DestinationId = g.Key, Count = g.Count() })
                .ToListAsync(cancellationToken);
            var favoritesById = favoriteCounts.ToDictionary(f => f.DestinationId, f => f.Count);

            var rows = new List<PopularDestinationRow>();
            var rank = 1;
            foreach (var entry in perDestination)
            {
                var meta = metadataById.GetValueOrDefault(entry.DestinationId);
                rows.Add(new PopularDestinationRow
                {
                    Rank = rank++,
                    DestinationName = meta?.Name ?? string.Empty,
                    CategoryName = meta?.Category ?? string.Empty,
                    RegionName = meta?.Region ?? string.Empty,
                    Bookings = entry.Bookings,
                    Travelers = entry.Travelers,
                    Views = meta?.ViewCount ?? 0,
                    Favorites = favoritesById.GetValueOrDefault(entry.DestinationId)
                });
            }

            string? categoryName = null;
            if (search.CategoryId is int categoryId)
            {
                categoryName = await _dbContext.DestinationCategories.AsNoTracking()
                    .Where(c => c.Id == categoryId)
                    .Select(c => c.Name)
                    .FirstOrDefaultAsync(cancellationToken);
            }

            return new PopularDestinationsReport
            {
                FromDate = search.FromDate,
                ToDate = search.ToDate,
                CategoryName = categoryName,
                Rows = rows
            };
        }

        public async Task<RevenueReport> GetRevenueReportAsync(
            RevenueReportSearch search, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var captured = _dbContext.Payments.AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Succeeded
                            || p.Status == PaymentStatus.Refunded
                            || p.Status == PaymentStatus.PartiallyRefunded);
            if (search.FromDate is DateTime from)
            {
                captured = captured.Where(p => p.CreatedAt >= from);
            }
            if (search.ToDate is DateTime to)
            {
                captured = captured.Where(p => p.CreatedAt < to);
            }

            // Attribute each captured payment to its tour's primary (first-ordered) destination and pull
            // that destination's category and region, plus the payment's own refunded total. The DB does
            // the filtering and the per-payment projection; the two GroupBys fold this bounded, minimal
            // result set (one small row per captured payment in the period) in memory.
            var projected = await captured
                .Select(p => new
                {
                    Category = p.Booking.TourSchedule.Tour.TourDestinations
                        .OrderBy(td => td.SortOrder)
                        .Select(td => td.Destination.Category.Name)
                        .FirstOrDefault(),
                    Region = p.Booking.TourSchedule.Tour.TourDestinations
                        .OrderBy(td => td.SortOrder)
                        .Select(td => td.Destination.City.Region.Name)
                        .FirstOrDefault(),
                    p.Amount,
                    Refunded = p.Refunds.Sum(r => (decimal?)r.Amount) ?? 0m
                })
                .ToListAsync(cancellationToken);

            var byCategory = GroupRevenue(projected.Select(x => (x.Category, x.Amount, x.Refunded)));
            var byRegion = GroupRevenue(projected.Select(x => (x.Region, x.Amount, x.Refunded)));

            var totalGross = projected.Sum(x => x.Amount);
            var totalRefunded = projected.Sum(x => x.Refunded);

            return new RevenueReport
            {
                FromDate = search.FromDate,
                ToDate = search.ToDate,
                ByCategory = byCategory,
                ByRegion = byRegion,
                TotalGross = totalGross,
                TotalRefunded = totalRefunded,
                TotalNet = totalGross - totalRefunded,
                Currency = _paymentOptions.Currency
            };
        }

        public async Task<byte[]> GetPopularDestinationsPdfAsync(
            PopularDestinationsReportSearch search, CancellationToken cancellationToken = default)
        {
            // The data method carries the Admin guard; rendering is pure composition over the returned DTO.
            var report = await GetPopularDestinationsAsync(search, cancellationToken);
            return new PopularDestinationsDocument(report).GeneratePdf();
        }

        public async Task<byte[]> GetRevenuePdfAsync(
            RevenueReportSearch search, CancellationToken cancellationToken = default)
        {
            var report = await GetRevenueReportAsync(search, cancellationToken);
            return new RevenueReportDocument(report).GeneratePdf();
        }

        public async Task<OrganizerStatsResponse> GetOrganizerStatsAsync(CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Organizer);
            var organizerId = _authorization.RequireUserId();

            var now = DateTime.UtcNow;
            var windowStart = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc)
                .AddMonths(-(TrailingMonths - 1));

            var statusCounts = await _dbContext.Bookings.AsNoTracking()
                .Where(b => b.TourSchedule.Tour.OrganizerId == organizerId)
                .GroupBy(b => b.StatusId)
                .Select(g => new { StatusId = g.Key, Count = g.Count() })
                .ToListAsync(cancellationToken);
            int CountFor(BookingStatusCode code) =>
                statusCounts.FirstOrDefault(s => s.StatusId == (int)code)?.Count ?? 0;

            var capturedOrg = _dbContext.Payments.AsNoTracking()
                .Where(p => (p.Status == PaymentStatus.Succeeded
                             || p.Status == PaymentStatus.Refunded
                             || p.Status == PaymentStatus.PartiallyRefunded)
                            && p.Booking.TourSchedule.Tour.OrganizerId == organizerId);

            // One flat projection of the organizer's captured payments (tour, charge, its refunded total
            // and its snapshotted fee), folded in memory for both the org totals and the per-tour rows so
            // gross, refunds, commission and net earnings all reconcile from the same source.
            var payments = await capturedOrg
                .Select(p => new PaymentRevenue
                {
                    TourId = p.Booking.TourSchedule.TourId,
                    Amount = p.Amount,
                    Refunded = p.Refunds.Sum(r => (decimal?)r.Amount) ?? 0m,
                    Fee = p.PlatformFeeAmount
                })
                .ToListAsync(cancellationToken);

            var gross = payments.Sum(x => x.Amount);
            var refunded = payments.Sum(x => x.Refunded);
            // Commission on retained funds: each payment's fee scaled by the un-refunded fraction of its
            // charge. Net earnings = gross − refunds − commission (the organizer's share; never paid out).
            var commission = Math.Round(payments.Sum(CommissionOf), 2, MidpointRounding.AwayFromZero);
            var netEarnings = gross - refunded - commission;

            var reviews = _dbContext.TourReviews.AsNoTracking()
                .Where(tr => !tr.IsRemoved && tr.Tour.OrganizerId == organizerId);
            var reviewCount = await reviews.CountAsync(cancellationToken);
            var averageRating = reviewCount == 0
                ? 0d
                : await reviews.AverageAsync(tr => (double)tr.Rating, cancellationToken);

            var bookingsPerMonth = await BuildBookingsPerMonthAsync(
                _dbContext.Bookings.Where(b => ChartStatusIds.Contains(b.StatusId)
                                               && b.TourSchedule.Tour.OrganizerId == organizerId),
                windowStart, cancellationToken);

            var tours = await BuildOrganizerTourRowsAsync(organizerId, payments, cancellationToken);

            return new OrganizerStatsResponse
            {
                TotalBookings = CountFor(BookingStatusCode.Pending) + CountFor(BookingStatusCode.Confirmed)
                                + CountFor(BookingStatusCode.Completed) + CountFor(BookingStatusCode.Cancelled),
                PendingBookings = CountFor(BookingStatusCode.Pending),
                ConfirmedBookings = CountFor(BookingStatusCode.Confirmed),
                CompletedBookings = CountFor(BookingStatusCode.Completed),
                CancelledBookings = CountFor(BookingStatusCode.Cancelled),
                GrossRevenue = gross,
                TotalRefunded = refunded,
                PlatformCommission = commission,
                NetEarnings = netEarnings,
                AverageRating = averageRating,
                ReviewCount = reviewCount,
                Currency = _paymentOptions.Currency,
                BookingsPerMonth = bookingsPerMonth,
                Tours = tours
            };
        }

        public async Task<CuratorStatsResponse> GetCuratorStatsAsync(CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Curator);
            var curatorId = _authorization.RequireUserId();

            // The curator's own submissions (a small, bounded set): one projection feeds the portfolio
            // counts and the total view count. Every other headline figure is a single DB aggregate scoped
            // to this curator through a navigation, so nothing unbounded is ever folded in memory.
            var portfolio = await _dbContext.Destinations.AsNoTracking()
                .Where(d => d.SubmittedByUserId == curatorId)
                .Select(d => new { d.Status, d.ViewCount })
                .ToListAsync(cancellationToken);
            int StatusCount(DestinationStatus status) => portfolio.Count(d => d.Status == status);

            var totalFavorites = await _dbContext.Favorites.AsNoTracking()
                .CountAsync(f => f.Destination!.SubmittedByUserId == curatorId, cancellationToken);

            var reviews = _dbContext.DestinationReviews.AsNoTracking()
                .Where(r => !r.IsRemoved && r.Destination.SubmittedByUserId == curatorId);
            var reviewCount = await reviews.CountAsync(cancellationToken);
            var averageRating = reviewCount == 0
                ? 0d
                : await reviews.AverageAsync(r => (double)r.Rating, cancellationToken);

            // Distinct bookings whose tour visits at least one of the curator's destinations — a booking
            // touching two of them still counts once — plus the travelers on those bookings.
            var reachBookings = _dbContext.Bookings.AsNoTracking()
                .Where(b => BookedStatusIds.Contains(b.StatusId)
                            && b.TourSchedule.Tour.TourDestinations
                                .Any(td => td.Destination.SubmittedByUserId == curatorId));
            var totalBookings = await reachBookings.CountAsync(cancellationToken);
            var totalTravelers = await reachBookings.SumAsync(b => (int?)b.NumberOfPeople, cancellationToken) ?? 0;

            return new CuratorStatsResponse
            {
                TotalDestinations = portfolio.Count,
                ApprovedDestinations = StatusCount(DestinationStatus.Approved),
                PendingDestinations = StatusCount(DestinationStatus.Pending),
                RejectedDestinations = StatusCount(DestinationStatus.Rejected),
                TotalViews = portfolio.Sum(d => d.ViewCount),
                TotalFavorites = totalFavorites,
                AverageRating = averageRating,
                ReviewCount = reviewCount,
                TotalBookings = totalBookings,
                TotalTravelers = totalTravelers
            };
        }

        public async Task<PageResult<CuratorDestinationStatRow>> GetCuratorDestinationsAsync(
            CuratorDestinationsSearch search, CancellationToken cancellationToken = default)
        {
            _authorization.EnsureInRole(RoleNames.Curator);
            var curatorId = _authorization.RequireUserId();

            var query = _dbContext.Destinations.AsNoTracking()
                .Where(d => d.SubmittedByUserId == curatorId);

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync(cancellationToken);
            }

            var pageNumber = search.Page ?? 1;
            if (pageNumber < 1)
            {
                pageNumber = 1;
            }
            var pageSize = search.PageSize ?? DefaultPageSize;
            if (pageSize < 1)
            {
                pageSize = DefaultPageSize;
            }
            if (pageSize > MaxPageSize)
            {
                pageSize = MaxPageSize;
            }

            // Project each destination with its engagement and per-stop reach computed at the DB (correlated
            // aggregates), ordered by impact so infinite scroll walks the most valuable submissions first.
            // A per-destination booking count attributes a booking to every curator stop its tour visits, so
            // these rows can sum above the headline's distinct-booking total — expected, and labelled so.
            var pageRows = await query
                .Select(d => new
                {
                    d.Name,
                    d.Status,
                    d.ViewCount,
                    Favorites = _dbContext.Favorites.Count(f => f.DestinationId == d.Id),
                    ReviewCount = d.Reviews.Count(r => !r.IsRemoved),
                    RatingSum = d.Reviews.Where(r => !r.IsRemoved).Sum(r => (double?)r.Rating) ?? 0d,
                    Bookings = _dbContext.Bookings.Count(b => BookedStatusIds.Contains(b.StatusId)
                        && b.TourSchedule.Tour.TourDestinations.Any(td => td.DestinationId == d.Id)),
                    Travelers = _dbContext.Bookings
                        .Where(b => BookedStatusIds.Contains(b.StatusId)
                            && b.TourSchedule.Tour.TourDestinations.Any(td => td.DestinationId == d.Id))
                        .Sum(b => (int?)b.NumberOfPeople) ?? 0
                })
                .OrderByDescending(x => x.Bookings)
                .ThenByDescending(x => x.ViewCount)
                .ThenBy(x => x.Name)
                .Skip((pageNumber - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(cancellationToken);

            var rows = pageRows
                .Select(x => new CuratorDestinationStatRow
                {
                    DestinationName = x.Name,
                    Status = x.Status.ToString(),
                    Views = x.ViewCount,
                    Favorites = x.Favorites,
                    AverageRating = x.ReviewCount == 0 ? 0d : x.RatingSum / x.ReviewCount,
                    ReviewCount = x.ReviewCount,
                    Bookings = x.Bookings,
                    Travelers = x.Travelers
                })
                .ToList();

            return new PageResult<CuratorDestinationStatRow>
            {
                Items = rows,
                TotalCount = totalCount
            };
        }

        // Groups a projected (key, gross, refunded) sequence into revenue rows, newest-biggest first.
        // Null keys (a tour with no destination — never expected) fall into an "Unattributed" bucket.
        private static List<RevenueGroupRow> GroupRevenue(IEnumerable<(string? Key, decimal Amount, decimal Refunded)> source)
        {
            return source
                .GroupBy(x => x.Key ?? "Unattributed")
                .Select(g =>
                {
                    var gross = g.Sum(x => x.Amount);
                    var refunded = g.Sum(x => x.Refunded);
                    return new RevenueGroupRow
                    {
                        GroupName = g.Key,
                        Bookings = g.Count(),
                        GrossRevenue = gross,
                        Refunded = refunded,
                        NetRevenue = gross - refunded
                    };
                })
                .OrderByDescending(r => r.NetRevenue)
                .ThenBy(r => r.GroupName)
                .ToList();
        }

        // Per-tour breakdown for the organizer screen. Bookings and ratings come from two grouped queries;
        // revenue is folded from the shared <paramref name="payments"/> projection so each tour's net
        // earnings (gross − refunds − commission) reconcile with the headline totals. No query in a loop.
        private async Task<List<OrganizerTourStatRow>> BuildOrganizerTourRowsAsync(
            int organizerId, List<PaymentRevenue> payments, CancellationToken cancellationToken)
        {
            var tours = await _dbContext.Tours.AsNoTracking()
                .Where(t => t.OrganizerId == organizerId)
                .Select(t => new { t.Id, t.Name })
                .ToListAsync(cancellationToken);
            if (tours.Count == 0)
            {
                return [];
            }

            var bookingsPerTour = await _dbContext.Bookings.AsNoTracking()
                .Where(b => b.TourSchedule.Tour.OrganizerId == organizerId
                            && BookedStatusIds.Contains(b.StatusId))
                .GroupBy(b => b.TourSchedule.TourId)
                .Select(g => new { TourId = g.Key, Count = g.Count() })
                .ToListAsync(cancellationToken);
            var bookingsById = bookingsPerTour.ToDictionary(x => x.TourId, x => x.Count);

            var netEarningsByTour = payments
                .GroupBy(x => x.TourId)
                .ToDictionary(
                    g => g.Key,
                    g => g.Sum(x => x.Amount) - g.Sum(x => x.Refunded)
                         - Math.Round(g.Sum(CommissionOf), 2, MidpointRounding.AwayFromZero));

            var ratingPerTour = await _dbContext.TourReviews.AsNoTracking()
                .Where(tr => !tr.IsRemoved && tr.Tour.OrganizerId == organizerId)
                .GroupBy(tr => tr.TourId)
                .Select(g => new { TourId = g.Key, Average = g.Average(tr => (double)tr.Rating), Count = g.Count() })
                .ToListAsync(cancellationToken);
            var ratingById = ratingPerTour.ToDictionary(x => x.TourId);

            return tours
                .Select(t =>
                {
                    var rating = ratingById.GetValueOrDefault(t.Id);
                    return new OrganizerTourStatRow
                    {
                        TourName = t.Name,
                        Bookings = bookingsById.GetValueOrDefault(t.Id),
                        NetEarnings = netEarningsByTour.GetValueOrDefault(t.Id),
                        AverageRating = rating?.Average ?? 0d,
                        ReviewCount = rating?.Count ?? 0
                    };
                })
                .OrderByDescending(r => r.Bookings)
                .ThenBy(r => r.TourName)
                .ToList();
        }

        // Commission actually earned on one captured payment: its snapshotted fee scaled by the fraction
        // of the charge that was not refunded. Amount is always > 0 for a captured payment, so the
        // division is safe.
        private static decimal CommissionOf(PaymentRevenue payment) =>
            payment.Fee * (payment.Amount - payment.Refunded) / payment.Amount;

        // Flat per-payment revenue projection (materialized once), folded in memory for the organizer's
        // headline totals and per-tour rows so every figure reconciles from the same source.
        private sealed class PaymentRevenue
        {
            public int TourId { get; set; }
            public decimal Amount { get; set; }
            public decimal Refunded { get; set; }
            public decimal Fee { get; set; }
        }

        // Counts bookings per calendar month over a pre-filtered query, then returns a continuous
        // trailing-12-month series (missing months filled with zero) with ready-to-render labels.
        private static async Task<List<MonthlyBookingPoint>> BuildBookingsPerMonthAsync(
            IQueryable<Booking> query, DateTime windowStart, CancellationToken cancellationToken)
        {
            var raw = await query
                .Where(b => b.CreatedAt >= windowStart)
                .GroupBy(b => new { b.CreatedAt.Year, b.CreatedAt.Month })
                .Select(g => new { g.Key.Year, g.Key.Month, Count = g.Count() })
                .ToListAsync(cancellationToken);
            var countByMonth = raw.ToDictionary(x => (x.Year, x.Month), x => x.Count);

            var series = new List<MonthlyBookingPoint>(TrailingMonths);
            var cursor = windowStart;
            for (var i = 0; i < TrailingMonths; i++)
            {
                series.Add(new MonthlyBookingPoint
                {
                    Year = cursor.Year,
                    Month = cursor.Month,
                    Count = countByMonth.GetValueOrDefault((cursor.Year, cursor.Month)),
                    Label = $"{MonthAbbreviations[cursor.Month - 1]} {cursor.Year}"
                });
                cursor = cursor.AddMonths(1);
            }
            return series;
        }

        // Merges the most-recent bookings, role applications and destination submissions into one
        // newest-first activity feed. Three bounded queries; names only, never raw IDs (course §K).
        private async Task<List<DashboardActivityItem>> BuildRecentActivityAsync(CancellationToken cancellationToken)
        {
            var recentBookings = await _dbContext.Bookings.AsNoTracking()
                .Where(b => b.StatusId != (int)BookingStatusCode.PaymentInProgress)
                .OrderByDescending(b => b.CreatedAt)
                .Take(RecentActivityCount)
                .Select(b => new DashboardActivityItem
                {
                    Kind = "Booking",
                    Title = "New booking",
                    Description = b.User.FirstName + " " + b.User.LastName
                                  + " booked '" + b.TourSchedule.Tour.Name + "'",
                    Timestamp = b.CreatedAt
                })
                .ToListAsync(cancellationToken);

            var recentApplications = await _dbContext.RoleApplications.AsNoTracking()
                .OrderByDescending(r => r.CreatedAt)
                .Take(RecentActivityCount)
                .Select(r => new DashboardActivityItem
                {
                    Kind = "RoleApplication",
                    Title = "Role application",
                    Description = r.User.FirstName + " " + r.User.LastName + " applied for " + r.Role.Name,
                    Timestamp = r.CreatedAt
                })
                .ToListAsync(cancellationToken);

            var recentDestinations = await _dbContext.Destinations.AsNoTracking()
                .OrderByDescending(d => d.CreatedAt)
                .Take(RecentActivityCount)
                .Select(d => new DashboardActivityItem
                {
                    Kind = "Destination",
                    Title = "Destination submitted",
                    Description = d.SubmittedByUser.FirstName + " " + d.SubmittedByUser.LastName
                                  + " submitted '" + d.Name + "'",
                    Timestamp = d.CreatedAt
                })
                .ToListAsync(cancellationToken);

            return recentBookings
                .Concat(recentApplications)
                .Concat(recentDestinations)
                .OrderByDescending(a => a.Timestamp)
                .Take(RecentActivityCount)
                .ToList();
        }
    }
}
