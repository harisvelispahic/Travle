namespace Travle.Services.Database
{
    /// <summary>
    /// A Stripe PaymentIntent tied to a <see cref="Booking"/>. Financial record — never deleted. The
    /// platform fee is snapshotted per payment (<see cref="PlatformFeePercentage"/>/<see cref="PlatformFeeAmount"/>)
    /// from configuration at charge time. Currency is stored as "bam" (displayed as KM).
    /// </summary>
    public class Payment : BaseEntity
    {
        public int BookingId { get; set; }
        public Booking Booking { get; set; } = null!;

        public string StripePaymentIntentId { get; set; } = string.Empty;

        public decimal Amount { get; set; }
        public string Currency { get; set; } = "bam";

        public decimal PlatformFeePercentage { get; set; }
        public decimal PlatformFeeAmount { get; set; }

        public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
        public DateTime? SucceededAt { get; set; }

        public ICollection<Refund> Refunds { get; set; } = new List<Refund>();
    }
}
