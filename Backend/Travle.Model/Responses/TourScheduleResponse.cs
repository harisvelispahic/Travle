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

        /// <summary>
        /// IANA zone (e.g. "Europe/Sarajevo") <see cref="StartsAt"/>/<see cref="EndsAt"/> display in — the
        /// tour's ordered-first destination's city zone. Those are UTC instants; the client converts them
        /// to this zone for display, labelled "(local time)". See docs/time-and-timezones.md.
        /// </summary>
        public string TimeZoneId { get; set; } = string.Empty;

        public int Capacity { get; set; }
        public int SeatsTaken { get; set; }

        /// <summary>Live free seats (<c>Capacity - SeatsTaken</c>), never below zero.</summary>
        public int FreeSeats { get; set; }

        /// <summary>
        /// Every booking row ever made on this slot — unlike <see cref="SeatsTaken"/>, which counts only
        /// bookings currently holding seats, this includes cancelled and expired ones. It is what blocks a
        /// hard delete (those rows are audit evidence), so it is the figure behind
        /// <see cref="IsDeletable"/> and <see cref="DeleteBlockedReason"/>.
        /// </summary>
        public int BookingCount { get; set; }

        /// <summary>Active / Cancelled — the enum name, never the raw int.</summary>
        public string Status { get; set; } = string.Empty;
        public string? CancelledReason { get; set; }
        public DateTime? CancelledAt { get; set; }

        /// <summary>
        /// When this departure stops accepting new bookings and completed payments: <see cref="StartsAt"/>
        /// minus the tour's booking cutoff (or the platform default). A UTC instant, displayed in
        /// <see cref="TimeZoneId"/> like the other event times.
        /// </summary>
        public DateTime BookingClosesAt { get; set; }

        /// <summary>
        /// True when a traveler can still book this slot right now: Active, before
        /// <see cref="BookingClosesAt"/>, and with a free seat. The clients gate their Book action on this
        /// rather than re-deriving the rule, so what they offer always matches what the server accepts.
        /// </summary>
        public bool IsBookable { get; set; }

        /// <summary>True when the slot is Active and still in the future (an organizer may cancel it).</summary>
        public bool IsCancellable { get; set; }

        /// <summary>
        /// True when the slot is Active, in the future and carries no booking rows at all — the exact
        /// condition <c>TourService.DeleteScheduleAsync</c> enforces, including cancelled and expired
        /// bookings, so the organizer desktop never offers a delete the server will refuse.
        /// </summary>
        public bool IsDeletable { get; set; }

        /// <summary>
        /// Why <see cref="IsDeletable"/> is false, for the desktop's disabled-with-reason tooltip (rule K).
        /// Null when the slot can be deleted.
        /// </summary>
        public string? DeleteBlockedReason { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
