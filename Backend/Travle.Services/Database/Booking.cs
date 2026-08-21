namespace Travle.Services.Database
{
    /// <summary>
    /// A reservation of seats on a <see cref="TourSchedule"/>. Status is a FK to <see cref="BookingStatus"/>
    /// and is only ever changed by the centralized state machine. Never hard-deleted — even Expired
    /// rows are audit evidence. <see cref="ExpiresAt"/> holds capacity for 15 min while PaymentInProgress.
    /// </summary>
    public class Booking : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int TourScheduleId { get; set; }
        public TourSchedule TourSchedule { get; set; } = null!;

        public int NumberOfPeople { get; set; }
        public decimal TotalAmount { get; set; }

        public int StatusId { get; set; }
        public BookingStatus Status { get; set; } = null!;
        public DateTime StatusChangedAt { get; set; }

        public int? ConfirmedByUserId { get; set; }
        public User? ConfirmedByUser { get; set; }
        public string? RejectionReason { get; set; }

        public int? CancelledByUserId { get; set; }
        public User? CancelledByUser { get; set; }
        public string? CancellationReason { get; set; }

        public DateTime? ExpiresAt { get; set; }

        /// <summary>
        /// Random per-booking seed for the Stripe idempotency keys of this booking's payment attempts
        /// (and their refunds). Idempotency keys must be identical for two calls that mean the same
        /// attempt and different for calls that don't — so the key cannot be built from the booking id
        /// alone: a database re-seed hands that id to an unrelated booking with a different amount, and
        /// Stripe (which remembers a key for 24 hours together with the parameters it first saw) rejects
        /// the mismatch. This token is minted once, here, and never reused.
        /// </summary>
        public string PaymentIdempotencyToken { get; set; } = Guid.NewGuid().ToString("N");

        public ICollection<Payment> Payments { get; set; } = new List<Payment>();
    }
}
