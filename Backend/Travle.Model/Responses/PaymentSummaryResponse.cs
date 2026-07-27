namespace Travle.Model.Responses
{
    /// <summary>
    /// Aggregate totals for the admin payments screen, computed over the same filter as the list. "Captured"
    /// = payments that were actually charged (Succeeded / Refunded / PartiallyRefunded). Commission is the
    /// snapshotted 10% platform fee — bookkeeping only, no organizer payouts.
    /// </summary>
    public class PaymentSummaryResponse
    {
        /// <summary>How many payments were captured (money actually taken).</summary>
        public int CapturedCount { get; set; }

        /// <summary>Gross amount captured (sum of charged amounts, before refunds).</summary>
        public decimal GrossRevenue { get; set; }

        /// <summary>Platform commission captured (sum of the snapshotted platform-fee amounts).</summary>
        public decimal PlatformCommission { get; set; }

        /// <summary>Gross minus commission — the organizers' notional share (never actually paid out).</summary>
        public decimal OrganizerShare { get; set; }

        /// <summary>Total refunded (sum of refund amounts) and how many refunds.</summary>
        public decimal TotalRefunded { get; set; }
        public int RefundCount { get; set; }

        /// <summary>Gross captured minus total refunded — money the platform actually kept.</summary>
        public decimal NetRevenue { get; set; }

        public string Currency { get; set; } = "bam";
    }
}
