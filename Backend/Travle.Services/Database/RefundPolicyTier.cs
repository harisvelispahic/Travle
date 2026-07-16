namespace Travle.Services.Database
{
    /// <summary>
    /// Reference table. A single global refund ladder keyed on how many hours before the slot the
    /// user cancels: >72h = 100%, 24–72h = 50%, 1–24h = 25%, &lt;1h = 0%. No FK points at a tier —
    /// refunds snapshot <see cref="Refund.PercentageApplied"/> — so tiers stay freely editable.
    /// <see cref="HoursBeforeMax"/> null = unbounded upper end.
    /// </summary>
    public class RefundPolicyTier : BaseEntity
    {
        public int HoursBeforeMin { get; set; }
        public int? HoursBeforeMax { get; set; }
        public int Percentage { get; set; }
    }
}
