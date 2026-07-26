namespace Travle.Model.Requests
{
    /// <summary>
    /// A new schedule slot for a tour (the tour is taken from the route, never the body). The organizer
    /// picks the start only — the end is derived server-side as <c>StartsAt + tour.DurationMinutes</c>,
    /// so a slot can never contradict the tour's stated duration. <see cref="Capacity"/> is optional and
    /// defaults to the tour's capacity when omitted.
    /// </summary>
    public class TourScheduleInsertRequest
    {
        public DateTime StartsAt { get; set; }

        /// <summary>Per-slot capacity; when null the tour's default capacity is used.</summary>
        public int? Capacity { get; set; }
    }
}
