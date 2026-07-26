namespace Travle.Model.Responses
{
    /// <summary>
    /// A single date/time slot of a tour with its live seat picture. <see cref="FreeSeats"/> is the
    /// derived <c>Capacity - SeatsTaken</c> the mobile app shows travelers; <see cref="SeatsTaken"/> is
    /// maintained transactionally by the Phase-5 booking capacity guard, so this value becomes "live"
    /// the moment bookings start writing it. The <see cref="IsCancellable"/>/<see cref="IsDeletable"/>
    /// flags let the organizer desktop render slot actions as disabled-with-reason (rule K).
    /// </summary>
    public class TourScheduleResponse
    {
        public int Id { get; set; }
        public int TourId { get; set; }

        public DateTime StartsAt { get; set; }
        public DateTime EndsAt { get; set; }

        public int Capacity { get; set; }
        public int SeatsTaken { get; set; }

        /// <summary>Live free seats (<c>Capacity - SeatsTaken</c>), never below zero.</summary>
        public int FreeSeats { get; set; }

        /// <summary>Active / Cancelled — the enum name, never the raw int.</summary>
        public string Status { get; set; } = string.Empty;
        public string? CancelledReason { get; set; }
        public DateTime? CancelledAt { get; set; }

        /// <summary>True when the slot is Active and still in the future (an organizer may cancel it).</summary>
        public bool IsCancellable { get; set; }

        /// <summary>True when the slot is Active, in the future and has no bookings (a typo slot may be hard-deleted).</summary>
        public bool IsDeletable { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
