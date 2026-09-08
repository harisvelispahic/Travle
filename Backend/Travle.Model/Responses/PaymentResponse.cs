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

        /// <summary>
        /// True when this captured payment sits on a cancelled booking but carries no refund yet — i.e. a
        /// refund is owed (an automatic attempt failed). Drives the admin "Retry refund" action.
        /// </summary>
        public bool RefundOwed { get; set; }

        /// <summary>
        /// The refund amount and percentage the booking recorded when it was cancelled — what a retry will
        /// pay, to the fening. Present for any cancelled booking (whether or not the refund went through),
        /// so an owed refund can be shown as a concrete figure rather than an open question. Null for a
        /// booking that was never cancelled.
        /// </summary>
        public decimal? RefundOwedAmount { get; set; }

        /// <summary>The percentage behind <see cref="RefundOwedAmount"/>; null on the same terms.</summary>
        public int? RefundOwedPercentage { get; set; }

        /// <summary>
        /// Who or what cancelled the booking (the enum name) — the reason that percentage is what it is.
        /// Null for a booking that was never cancelled.
        /// </summary>
        public string? CancellationSource { get; set; }

        /// <summary>When the booking was cancelled; null if it never was.</summary>
        public DateTime? CancelledAt { get; set; }

        public DateTime? SucceededAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}
