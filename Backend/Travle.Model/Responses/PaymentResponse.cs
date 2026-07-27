namespace Travle.Model.Responses
{
    /// <summary>
    /// A payment as shown on the admin payments screen. Reference fields are flattened to names (traveler,
    /// tour) — never raw ids on screen. <see cref="Status"/> is the enum name; <see cref="RefundedAmount"/>
    /// is the sum of refunds against this payment. Financial records are read-only (never CRUD-edited).
    /// </summary>
    public class PaymentResponse
    {
        public int Id { get; set; }

        public int BookingId { get; set; }
        public string TravelerName { get; set; } = string.Empty;
        public string TravelerUsername { get; set; } = string.Empty;
        public string TourName { get; set; } = string.Empty;

        public decimal Amount { get; set; }
        public string Currency { get; set; } = "bam";

        public decimal PlatformFeePercentage { get; set; }
        public decimal PlatformFeeAmount { get; set; }

        /// <summary>Pending / Succeeded / Failed / Refunded / PartiallyRefunded — the enum name.</summary>
        public string Status { get; set; } = string.Empty;

        /// <summary>Total refunded against this payment (0 when none); and how many refunds.</summary>
        public decimal RefundedAmount { get; set; }
        public int RefundCount { get; set; }

        public DateTime? SucceededAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
