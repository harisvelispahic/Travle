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
        /// True when this captured payment still owes money back and carries no refund yet, because an
        /// automatic attempt failed. Two cases qualify: a cancelled booking, which owes the obligation it
        /// recorded, and a charge captured against a booking that was never honoured at all (expired, or
        /// refused by the amount guard), which owes the whole amount. Drives the admin "Retry refund"
        /// action, and is resolved by the same rule that endpoint enforces.
        /// </summary>
        public bool RefundOwed { get; set; }

        /// <summary>
        /// What a retry will pay, to the fening: the figure the booking recorded when it was cancelled, or
        /// the whole captured charge when there was no cancellation to record one. Present for any cancelled
        /// booking (whether or not the refund went through) so an owed refund reads as a concrete figure
        /// rather than an open question. Null when nothing is or was owed.
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
