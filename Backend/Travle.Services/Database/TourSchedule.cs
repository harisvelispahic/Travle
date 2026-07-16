namespace Travle.Services.Database
{
    /// <summary>
    /// A concrete date/time slot of a <see cref="Tour"/> with its own capacity. <see cref="SeatsTaken"/>
    /// is maintained transactionally by the booking capacity guard (03 §6). Cancellation is a status
    /// change (Cancelled + reason + mass refund), not a delete.
    /// </summary>
    public class TourSchedule : BaseEntity
    {
        public int TourId { get; set; }
        public Tour Tour { get; set; } = null!;

        public DateTime StartsAt { get; set; }
        public DateTime EndsAt { get; set; }

        public int Capacity { get; set; }
        public int SeatsTaken { get; set; }

        public ScheduleStatus Status { get; set; } = ScheduleStatus.Active;
        public string? CancelledReason { get; set; }
        public DateTime? CancelledAt { get; set; }

        public ICollection<Booking> Bookings { get; set; } = new List<Booking>();
    }
}
