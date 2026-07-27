namespace Travle.Model.Responses
{
    /// <summary>
    /// Aggregate totals for the admin payments screen, computed over the same filter as the list. "Captured"
    /// = payments that were actually charged (Succeeded / Refunded / PartiallyRefunded). Commission is the
    /// snapshotted 10% platform fee — bookkeeping only, no organizer payouts — reduced in proportion to any
    /// refunds so it reflects only the funds the platform actually kept.
    /// </summary>
    public class PaymentSummaryResponse
    {
        /// <summary>How many payments were captured (money actually taken).</summary>
        public int CapturedCount { get; set; }

        /// <summary>Gross amount captured (sum of charged amounts, before refunds).</summary>
        public decimal GrossRevenue { get; set; }

        /// <summary>
        /// Platform commission on the retained funds: each payment's snapshotted platform fee scaled by the
        /// fraction of its charge that was not refunded. Commission on refunded amounts is not counted.
        /// </summary>
        public decimal PlatformCommission { get; set; }

        /// <summary>Net revenue minus commission — the organizers' notional share (never actually paid out).</summary>
        public decimal OrganizerShare { get; set; }

        /// <summary>Total refunded (sum of refund amounts) and how many refunds.</summary>
        public decimal TotalRefunded { get; set; }
        public int RefundCount { get; set; }

        /// <summary>Gross captured minus total refunded — money the platform actually kept.</summary>
        public decimal NetRevenue { get; set; }

        public string Currency { get; set; } = "bam";
    }
}
