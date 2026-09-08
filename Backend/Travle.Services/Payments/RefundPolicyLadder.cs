using Travle.Model.Exceptions;
using Travle.Services.Database;

namespace Travle.Services.Payments
{
    /// <summary>
    /// Validates the refund tiers as one ladder rather than as independent rows.
    ///
    /// Each tier is individually sane on its own terms (the FluentValidation validators see to that), but
    /// the tiers only mean something together: <see cref="PaymentMath.ResolveRefundPercentageAsync"/> asks
    /// "how many hours before departure is this cancellation, and what does the policy say?" — a question
    /// that has a single honest answer only if the tiers tile the whole range from 0 hours to infinity with
    /// no gap and no overlap. Without that, an overlap resolves arbitrarily by sort order and a gap silently
    /// yields 0%, both of which decide real money.
    ///
    /// So every write is checked against the ladder it would <b>produce</b>, not against the row being
    /// changed: insert, update and delete all run through <see cref="EnsureContiguous"/> with the resulting
    /// set. The messages name the offending boundary and say what to do about it, because a contiguous
    /// ladder can rarely be fixed one row at a time — an admin usually has to widen a neighbour first.
    /// </summary>
    public static class RefundPolicyLadder
    {
        /// <summary>
        /// Throws unless <paramref name="tiers"/> covers every hour from 0 upwards exactly once: sorted by
        /// their lower bound, the first starts at 0, each one ends where the next begins, and precisely one
        /// — the last — is open-ended.
        /// </summary>
        public static void EnsureContiguous(IReadOnlyCollection<RefundPolicyTier> tiers)
        {
            if (tiers.Count == 0)
            {
                throw new BusinessRuleException(
                    "The refund policy must keep at least one tier — with none, every cancellation would "
                    + "silently refund 0%.");
            }

            var ordered = tiers.OrderBy(t => t.HoursBeforeMin).ToList();

            // Exactly one open end, and it must be the tier that starts last. Two open-ended tiers overlap
            // for ever; an open-ended tier in the middle swallows the ones above it.
            var openEnded = ordered.Where(t => t.HoursBeforeMax is null).ToList();
            if (openEnded.Count == 0)
            {
                var highest = ordered[^1];
                throw new BusinessRuleException(
                    $"The refund policy must cover every cancellation, however early. Leave the highest tier "
                    + $"(from {highest.HoursBeforeMin}h) open-ended by clearing its upper bound.");
            }
            if (openEnded.Count > 1)
            {
                throw new BusinessRuleException(
                    "Only one refund tier may be open-ended (the highest). "
                    + $"Tiers starting at {string.Join("h and ", openEnded.Select(t => t.HoursBeforeMin))}h both have no upper bound.");
            }
            if (ordered[^1].HoursBeforeMax is not null)
            {
                throw new BusinessRuleException(
                    $"The open-ended refund tier must be the highest one. The tier from "
                    + $"{openEnded[0].HoursBeforeMin}h has no upper bound but is not the last in the ladder.");
            }

            // The ladder has to start at the departure itself — otherwise a last-minute cancellation matches
            // nothing and falls through to 0% by accident rather than by policy.
            if (ordered[0].HoursBeforeMin != 0)
            {
                throw new BusinessRuleException(
                    $"The refund policy must start at 0 hours before departure, but its lowest tier starts at "
                    + $"{ordered[0].HoursBeforeMin}h. Cancellations inside that window would match no tier.");
            }

            // Each tier ends exactly where the next begins: a lower Max leaves hours uncovered, a higher one
            // makes two tiers claim the same hour.
            for (var i = 0; i < ordered.Count - 1; i++)
            {
                var current = ordered[i];
                var next = ordered[i + 1];

                if (current.HoursBeforeMax < next.HoursBeforeMin)
                {
                    throw new BusinessRuleException(
                        $"The refund policy leaves {current.HoursBeforeMax}h–{next.HoursBeforeMin}h before departure "
                        + "uncovered. Tiers must meet exactly: extend one of them so there is no gap.");
                }
                if (current.HoursBeforeMax > next.HoursBeforeMin)
                {
                    throw new BusinessRuleException(
                        $"The refund tiers {current.HoursBeforeMin}h–{current.HoursBeforeMax}h and "
                        + $"{next.HoursBeforeMin}h–{FormatUpper(next.HoursBeforeMax)} overlap. Each hour before departure "
                        + "must match exactly one tier.");
                }
            }
        }

        private static string FormatUpper(int? max) => max is int value ? $"{value}h" : "above";
    }
}
