namespace Travle.Services.Database
{
    /// <summary>
    /// Reference table. Seeded with the exact state-machine names (PaymentInProgress, Pending,
    /// Confirmed, Completed, Cancelled, Expired) — the deterministic Ids are referenced by the
    /// filtered unique index on <see cref="Booking"/> and by the state machine, so they must not change.
    /// </summary>
    public class BookingStatus : BaseEntity
    {
        public string Name { get; set; } = string.Empty;

        public ICollection<Booking> Bookings { get; set; } = new List<Booking>();
    }
}
