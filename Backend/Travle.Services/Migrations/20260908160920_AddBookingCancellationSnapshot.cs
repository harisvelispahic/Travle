using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Travle.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingCancellationSnapshot : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CancellationSource",
                table: "Bookings",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CancelledAt",
                table: "Bookings",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "RefundAmountOwed",
                table: "Bookings",
                type: "decimal(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "RefundPercentageOwed",
                table: "Bookings",
                type: "int",
                nullable: true);

            // ---- Backfill: give every already-cancelled booking the record this migration introduces ----
            //
            // Going forward the obligation is frozen by the cancelling transition itself. Rows cancelled
            // before that existed have no recorded decision, so this is the one honest moment to establish
            // one: reconstruct it from the audit trail now, and it is never recomputed again.
            //
            // Order matters — each step reads columns the previous one set.

            // 1. Cancelled is a terminal status, so the last status change IS the cancellation.
            migrationBuilder.Sql(@"
                UPDATE Bookings
                SET CancelledAt = StatusChangedAt
                WHERE StatusId = 5 AND CancelledAt IS NULL;");

            // 2. Source, only where the audit fields say so plainly. A cancellation by someone other than
            //    the traveler could be an organizer reject, an organizer cancel, a slot cancel or a
            //    suspension; only a reject leaves its own fingerprint (RejectionReason). The rest become
            //    Unknown (0) rather than being guessed at — a wrong audit label is worse than an honest gap.
            migrationBuilder.Sql(@"
                UPDATE Bookings
                SET CancellationSource = CASE
                        WHEN CancelledByUserId = UserId THEN 1   -- Traveler
                        WHEN RejectionReason IS NOT NULL THEN 3  -- OrganizerReject
                        ELSE 0                                   -- Unknown
                    END
                WHERE StatusId = 5 AND CancellationSource IS NULL;");

            // 3. Where a Refund row exists it is authoritative: that is the money that actually moved, and
            //    the percentage that was actually applied. Nothing to reconstruct.
            migrationBuilder.Sql(@"
                UPDATE b
                SET b.RefundPercentageOwed = r.PercentageApplied,
                    b.RefundAmountOwed     = r.Amount
                FROM Bookings b
                CROSS APPLY (
                    SELECT TOP 1 rf.PercentageApplied, rf.Amount
                    FROM Refunds rf
                    INNER JOIN Payments p ON p.Id = rf.PaymentId
                    WHERE p.BookingId = b.Id
                    ORDER BY rf.Id DESC
                ) r
                WHERE b.StatusId = 5 AND b.RefundPercentageOwed IS NULL;");

            // 4. No refund row: the refund either failed or was never owed. Reconstruct the percentage the
            //    way the cancellation itself would have decided it — the tier ladder for a traveler's own
            //    cancellation (resolved against when they cancelled, not now), a full refund for every other
            //    source, since only the traveler's own choice is ever tiered.
            migrationBuilder.Sql(@"
                UPDATE b
                SET b.RefundPercentageOwed = CASE
                        WHEN b.CancellationSource = 1 THEN ISNULL((
                            SELECT TOP 1 t.Percentage
                            FROM RefundPolicyTiers t
                            WHERE t.HoursBeforeMin <=
                                    CASE WHEN DATEDIFF(MINUTE, b.StatusChangedAt, s.StartsAt) < 0 THEN 0
                                         ELSE DATEDIFF(MINUTE, b.StatusChangedAt, s.StartsAt) / 60.0 END
                              AND (t.HoursBeforeMax IS NULL OR t.HoursBeforeMax >
                                    CASE WHEN DATEDIFF(MINUTE, b.StatusChangedAt, s.StartsAt) < 0 THEN 0
                                         ELSE DATEDIFF(MINUTE, b.StatusChangedAt, s.StartsAt) / 60.0 END)
                            ORDER BY t.HoursBeforeMin DESC), 0)
                        ELSE 100
                    END
                FROM Bookings b
                INNER JOIN TourSchedules s ON s.Id = b.TourScheduleId
                WHERE b.StatusId = 5 AND b.RefundPercentageOwed IS NULL;");

            // 5. The amount that percentage applies to is the charge actually captured (0 when the booking
            //    was cancelled before anyone paid). Statuses 1/3/4 = Succeeded / Refunded / PartiallyRefunded.
            migrationBuilder.Sql(@"
                UPDATE b
                SET b.RefundAmountOwed = ROUND(ISNULL((
                        SELECT SUM(p.Amount) FROM Payments p
                        WHERE p.BookingId = b.Id AND p.Status IN (1, 3, 4)
                    ), 0) * b.RefundPercentageOwed / 100.0, 2)
                FROM Bookings b
                WHERE b.StatusId = 5 AND b.RefundAmountOwed IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CancellationSource",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "CancelledAt",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "RefundAmountOwed",
                table: "Bookings");

            migrationBuilder.DropColumn(
                name: "RefundPercentageOwed",
                table: "Bookings");
        }
    }
}
