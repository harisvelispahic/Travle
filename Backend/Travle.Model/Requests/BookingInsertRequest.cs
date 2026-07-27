namespace Travle.Model.Requests
{
    /// <summary>
    /// A traveler's request to book a tour schedule. The user is taken from the JWT (never the client)
    /// and the total is computed server-side from the tour's price — only the slot and the group size
    /// come from the client. Creation enters the booking as PaymentInProgress and holds capacity for
    /// 15 minutes while payment completes.
    /// </summary>
    public class BookingInsertRequest
    {
        public int TourScheduleId { get; set; }

        /// <summary>Number of seats to reserve (checked against the slot's live free capacity server-side).</summary>
        public int NumberOfPeople { get; set; }
    }
}
