namespace Travle.Model.Requests
{
    /// <summary>
    /// An organizer's cancellation of a schedule slot. The reason is mandatory (course §L audit trail)
    /// and, from Phase 6, is carried into the automatic 100% refund + notification sent to every booking
    /// on the slot.
    /// </summary>
    public class TourScheduleCancelRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
