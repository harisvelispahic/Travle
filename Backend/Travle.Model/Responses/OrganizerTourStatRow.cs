namespace Travle.Model.Responses
{
    /// <summary>
    /// Per-tour line of the organizer statistics screen: how each of the organizer's own tours is
    /// performing. <see cref="NetEarnings"/> is captured minus refunds minus commission on that tour;
    /// <see cref="AverageRating"/> is 0 when the tour has no (non-removed) reviews yet.
    /// </summary>
    public class OrganizerTourStatRow
    {
        public string TourName { get; set; } = string.Empty;
        public int Bookings { get; set; }
        public decimal NetEarnings { get; set; }
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }
    }
}
