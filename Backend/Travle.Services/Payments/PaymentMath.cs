using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services.Payments
{
    /// <summary>
    /// The one place the payment money-maths live, so the create-intent path, the refund path and the
    /// cancellation refund <i>preview</i> can never drift apart (a previewed refund % must equal the one
    /// actually charged). All amounts are KM decimals; Stripe amounts are integer minor units (fening).
    /// </summary>
    public static class PaymentMath
    {
        /// <summary>KM (2-decimal) → Stripe minor units: 25.00 KM → 2500.</summary>
        public static long ToMinorUnits(decimal amount)
            => (long)Math.Round(amount * 100m, MidpointRounding.AwayFromZero);

        /// <summary>The refunded KM amount for a tier percentage of the actually-charged amount.</summary>
        public static decimal RefundAmount(decimal chargedAmount, int percentage)
            => Math.Round(chargedAmount * percentage / 100m, 2, MidpointRounding.AwayFromZero);

        /// <summary>
        /// Resolves the user-cancellation refund percentage from the global <c>RefundPolicyTiers</c> ladder
        /// by how many hours before the schedule start the cancellation lands (never negative). No matching
        /// tier ⇒ 0%. Shared by the pre-cancel preview and the actual refund execution.
        /// </summary>
        public static async Task<int> ResolveRefundPercentageAsync(
            TravleDbContext dbContext, DateTime scheduleStartsAt, DateTime nowUtc, CancellationToken cancellationToken = default)
        {
            var hoursBefore = Math.Max(0, (scheduleStartsAt - nowUtc).TotalHours);

            var tier = await dbContext.RefundPolicyTiers
                .AsNoTracking()
                .Where(t => hoursBefore >= t.HoursBeforeMin
                            && (t.HoursBeforeMax == null || hoursBefore < t.HoursBeforeMax))
                .OrderByDescending(t => t.HoursBeforeMin)
                .FirstOrDefaultAsync(cancellationToken);

            return tier?.Percentage ?? 0;
        }
    }
}
