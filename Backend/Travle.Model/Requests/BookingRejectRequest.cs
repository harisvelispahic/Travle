namespace Travle.Model.Requests
{
    /// <summary>
    /// An organizer's rejection of a pending booking. The reason is mandatory (course §L audit trail) and
    /// is shown to the traveler; an organizer rejection always refunds 100% of the charged amount (P6).
    /// </summary>
    public class BookingRejectRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
