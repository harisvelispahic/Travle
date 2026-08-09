using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Travle.Services.Database
{
    /// <summary>
    /// Idempotent runtime seed of historical bookings, payments and one refund spread across the trailing
    /// ~12 months, so the Phase 11 reports and the bookings-per-month chart open with real, non-trivial
    /// data (course §E "seed contains all data needed to test"). This is the sanctioned "rich data →
    /// runtime seeder" path (02 §4): the reference + core demo rows stay in <see cref="TravleSeed"/>
    /// (HasData/migration), while this bulk analytics data is inserted here so it needs no migration and
    /// can compute dates relative to "now". Guarded by a sentinel intent id so it runs exactly once.
    /// </summary>
    public static class HistoricalActivitySeeder
    {
        private const string IntentPrefix = "pi_hist_";
        private const decimal FeePercentage = 10m;

        private enum Kind { Completed, Confirmed, CancelledRefunded }

        // (monthsAgo, tourId, people, travelerUserId, kind). Chosen to spread bookings across every month,
        // several categories/regions (via each tour's primary destination) and all three organizers.
        private static readonly (int MonthsAgo, int TourId, int People, int TravelerId, Kind Kind)[] Entries =
        [
            (11, 1, 2, 4, Kind.Completed),
            (10, 3, 2, 5, Kind.Completed),
            (10, 7, 1, 4, Kind.Completed),
            (9, 2, 2, 4, Kind.Completed),
            (8, 9, 1, 5, Kind.Completed),
            (8, 5, 2, 4, Kind.Completed),
            (7, 8, 3, 5, Kind.Completed),
            (6, 6, 4, 5, Kind.Completed),
            (6, 4, 2, 5, Kind.CancelledRefunded),
            (5, 10, 2, 4, Kind.Completed),
            (4, 3, 3, 5, Kind.Completed),
            (4, 1, 2, 4, Kind.Completed),
            (4, 7, 2, 5, Kind.Completed),
            (3, 4, 2, 4, Kind.Completed),
            (2, 2, 2, 5, Kind.Completed),
            (1, 8, 2, 4, Kind.Completed),
            (1, 9, 1, 5, Kind.Completed),
            (0, 1, 2, 4, Kind.Confirmed),
            (0, 3, 2, 5, Kind.Confirmed),
        ];

        public static async Task SeedAsync(TravleDbContext dbContext, ILogger logger, CancellationToken cancellationToken = default)
        {
            var alreadySeeded = await dbContext.Payments
                .AnyAsync(p => p.StripePaymentIntentId.StartsWith(IntentPrefix), cancellationToken);
            if (alreadySeeded)
            {
                return;
            }

            var tours = await dbContext.Tours
                .Select(t => new { t.Id, t.PricePerPerson, t.Capacity, t.DurationMinutes, t.OrganizerId })
                .ToDictionaryAsync(t => t.Id, cancellationToken);

            var now = DateTime.UtcNow;
            var firstOfThisMonth = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);

            var index = 0;
            foreach (var entry in Entries)
            {
                if (!tours.TryGetValue(entry.TourId, out var tour))
                {
                    continue;
                }

                index++;
                var amount = tour.PricePerPerson * entry.People;
                var fee = Math.Round(amount * FeePercentage / 100m, 2, MidpointRounding.AwayFromZero);
                var monthStart = firstOfThisMonth.AddMonths(-entry.MonthsAgo);

                var payment = entry.Kind switch
                {
                    Kind.Confirmed => BuildCurrentMonth(entry, tour.Capacity, tour.DurationMinutes,
                        tour.OrganizerId, amount, fee, now, index),
                    _ => BuildPastMonth(entry, tour.Capacity, tour.DurationMinutes,
                        tour.OrganizerId, amount, fee, monthStart, index),
                };

                dbContext.Payments.Add(payment);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            logger.LogInformation("Seeded {Count} historical booking(s)/payment(s) for reporting.", index);
        }

        // A current-month Confirmed booking on a future slot with a payment taken now — feeds the dashboard's
        // "this month" revenue and the latest bar of the bookings-per-month chart.
        private static Payment BuildCurrentMonth(
            (int MonthsAgo, int TourId, int People, int TravelerId, Kind Kind) entry,
            int capacity, int durationMinutes, int organizerId, decimal amount, decimal fee, DateTime now, int index)
        {
            var createdAt = now.AddDays(-1);
            var scheduleStart = now.AddDays(20).Date.AddHours(9);
            var schedule = new TourSchedule
            {
                TourId = entry.TourId,
                StartsAt = scheduleStart,
                EndsAt = scheduleStart.AddMinutes(durationMinutes),
                Capacity = capacity,
                SeatsTaken = entry.People,
                Status = ScheduleStatus.Active,
                CreatedAt = createdAt,
            };

            var booking = new Booking
            {
                UserId = entry.TravelerId,
                TourSchedule = schedule,
                NumberOfPeople = entry.People,
                TotalAmount = amount,
                StatusId = (int)BookingStatusCode.Confirmed,
                StatusChangedAt = createdAt.AddHours(1),
                ConfirmedByUserId = organizerId,
                CreatedAt = createdAt,
            };

            return new Payment
            {
                Booking = booking,
                StripePaymentIntentId = $"{IntentPrefix}{index:D4}",
                Amount = amount,
                Currency = "bam",
                PlatformFeePercentage = FeePercentage,
                PlatformFeeAmount = fee,
                Status = PaymentStatus.Succeeded,
                SucceededAt = createdAt.AddMinutes(5),
                CreatedAt = createdAt.AddMinutes(4),
            };
        }

        // A past-month booking: Completed (schedule already ended) or Cancelled-and-refunded.
        private static Payment BuildPastMonth(
            (int MonthsAgo, int TourId, int People, int TravelerId, Kind Kind) entry,
            int capacity, int durationMinutes, int organizerId, decimal amount, decimal fee, DateTime monthStart, int index)
        {
            var createdAt = monthStart.AddDays(6).AddHours(10);
            var scheduleStart = monthStart.AddDays(12).AddHours(9);
            var cancelled = entry.Kind == Kind.CancelledRefunded;

            var schedule = new TourSchedule
            {
                TourId = entry.TourId,
                StartsAt = scheduleStart,
                EndsAt = scheduleStart.AddMinutes(durationMinutes),
                Capacity = capacity,
                SeatsTaken = cancelled ? 0 : entry.People, // a cancelled booking releases its seats
                Status = ScheduleStatus.Active,
                CreatedAt = createdAt,
            };

            var booking = new Booking
            {
                UserId = entry.TravelerId,
                TourSchedule = schedule,
                NumberOfPeople = entry.People,
                TotalAmount = amount,
                CreatedAt = createdAt,
            };

            var payment = new Payment
            {
                Booking = booking,
                StripePaymentIntentId = $"{IntentPrefix}{index:D4}",
                Amount = amount,
                Currency = "bam",
                PlatformFeePercentage = FeePercentage,
                PlatformFeeAmount = fee,
                SucceededAt = createdAt.AddMinutes(5),
                CreatedAt = createdAt.AddMinutes(4),
            };

            if (cancelled)
            {
                // Cancelled well before start → 50% tier on the charged amount, partially refunded.
                var refundAmount = Math.Round(amount * 50m / 100m, 2, MidpointRounding.AwayFromZero);
                booking.StatusId = (int)BookingStatusCode.Cancelled;
                booking.StatusChangedAt = createdAt.AddDays(2);
                booking.CancelledByUserId = entry.TravelerId;
                booking.CancellationReason = "Change of plans.";
                payment.Status = PaymentStatus.PartiallyRefunded;
                payment.Refunds.Add(new Refund
                {
                    StripeRefundId = $"re_hist_{index:D4}",
                    Amount = refundAmount,
                    PercentageApplied = 50,
                    Reason = "User cancellation 24–72 hours before start.",
                    InitiatedByUserId = entry.TravelerId,
                    CreatedAt = createdAt.AddDays(2).AddMinutes(2),
                });
            }
            else
            {
                booking.StatusId = (int)BookingStatusCode.Completed;
                booking.StatusChangedAt = schedule.EndsAt.AddHours(1);
                booking.ConfirmedByUserId = organizerId;
                payment.Status = PaymentStatus.Succeeded;
            }

            return payment;
        }
    }
}
