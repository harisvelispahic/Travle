namespace Travle.Model.Requests
{
    /// <summary>
    /// A traveler's cancellation of their own booking. The reason is optional; the refund percentage is
    /// resolved server-side from the global <c>RefundPolicyTiers</c> by how far ahead of the schedule the
    /// cancellation lands (the refund itself executes in Phase 6).
    /// </summary>
    public class BookingCancelRequest
    {
        public string? Reason { get; set; }
    }
}
