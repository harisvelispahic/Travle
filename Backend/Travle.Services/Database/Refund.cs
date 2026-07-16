namespace Travle.Services.Database
{
    /// <summary>
    /// A refund issued against a <see cref="Payment"/>. Financial record — never deleted.
    /// <see cref="PercentageApplied"/> is snapshotted from the refund tier that applied, and
    /// <see cref="Amount"/> is computed from the actually charged amount.
    /// </summary>
    public class Refund : BaseEntity
    {
        public int PaymentId { get; set; }
        public Payment Payment { get; set; } = null!;

        public string StripeRefundId { get; set; } = string.Empty;

        public decimal Amount { get; set; }
        public int PercentageApplied { get; set; }
        public string Reason { get; set; } = string.Empty;

        public int InitiatedByUserId { get; set; }
        public User InitiatedByUser { get; set; } = null!;
    }
}
