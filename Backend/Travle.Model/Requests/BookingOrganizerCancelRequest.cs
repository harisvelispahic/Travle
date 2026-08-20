namespace Travle.Model.Requests
{
    /// <summary>
    /// An organizer calling off a single <b>confirmed</b> booking on one of their tours (the per-booking
    /// counterpart of retiring a whole schedule). The reason is mandatory (course §L audit trail) and is
    /// shown to the traveler; like every organizer-initiated cancellation it refunds 100% of the charged
    /// amount regardless of how close the departure is (00 §1.4) — the tier ladder only applies when the
    /// traveler is the one backing out.
    /// </summary>
    public class BookingOrganizerCancelRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
