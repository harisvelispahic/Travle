namespace Travle.Model.Responses
{
    /// <summary>
    /// A traveler's reservation of seats on a tour schedule, as seen by the traveler (their history),
    /// the organizer (bookings on their tours) and the admin (all bookings). <see cref="Status"/> is the
    /// booking-status name, never the raw int; <see cref="AllowedActions"/> lists the transitions the
    /// booking currently permits (enum names) so each app renders exactly the buttons that will succeed.
    /// Only the small cover <see cref="TourThumbnail"/> travels — the tour's full images come from the
    /// destination image endpoint (rule 12). Status is only ever changed by the centralized state machine.
    /// </summary>
    public class BookingResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }
        public string TravelerName { get; set; } = string.Empty;
        public string TravelerUsername { get; set; } = string.Empty;

        public int TourScheduleId { get; set; }
        public DateTime ScheduleStartsAt { get; set; }
        public DateTime ScheduleEndsAt { get; set; }

        /// <summary>
        /// IANA zone (e.g. "Europe/Sarajevo") the schedule's event times display in — the tour's
        /// ordered-first destination's city zone. <see cref="ScheduleStartsAt"/>/<see cref="ScheduleEndsAt"/>
        /// are UTC instants; the client converts them to this zone, labelled "(local time)". Audit fields
        /// (<see cref="CreatedAt"/>, <see cref="ExpiresAt"/>, …) stay device-local. See docs/time-and-timezones.md.
        /// </summary>
        public string TimeZoneId { get; set; } = string.Empty;

        public int TourId { get; set; }
        public string TourName { get; set; } = string.Empty;

        /// <summary>The tour's organizer — so the traveler can open the organizer's public profile from
        /// their booking (name only; never the raw id on screen).</summary>
        public int OrganizerId { get; set; }
        public string OrganizerName { get; set; } = string.Empty;

        public int NumberOfPeople { get; set; }

        /// <summary>Server-computed total (price-per-person × people). Never trusted from the client.</summary>
        public decimal TotalAmount { get; set; }

        /// <summary>
        /// Sum of the tour's destinations' informative entrance fees (KM), <b>per person</b> — paid on-site,
        /// never part of the Travle charge. 0 when no stop has a fee. A "bring around X" guide only.
        /// </summary>
        public decimal EntranceFeesPerPerson { get; set; }

        public int StatusId { get; set; }

        /// <summary>PaymentInProgress / Pending / Confirmed / Completed / Cancelled / Expired — the name.</summary>
        public string Status { get; set; } = string.Empty;
        public DateTime StatusChangedAt { get; set; }

        public int? ConfirmedByUserId { get; set; }
        public string? ConfirmedByName { get; set; }
        public string? RejectionReason { get; set; }

        public int? CancelledByUserId { get; set; }
        public string? CancelledByName { get; set; }
        public string? CancellationReason { get; set; }

        /// <summary>When a PaymentInProgress hold lapses (15 min after checkout); null once past that state.</summary>
        public DateTime? ExpiresAt { get; set; }

        /// <summary>True once a Stripe payment has succeeded for this booking (drives "hide pay button").</summary>
        public bool IsPaid { get; set; }

        /// <summary>
        /// True when the viewer is this booking's traveler, the booking is Completed, and it has not been
        /// reviewed yet — the mobile shows the "Leave a review" action only then (rule K).
        /// </summary>
        public bool CanBeReviewed { get; set; }

        /// <summary>The id of this booking's tour review if one exists, else null (drives "Your review" / edit).</summary>
        public int? ReviewId { get; set; }

        /// <summary>The transitions currently allowed (enum names), for button gating (rule K).</summary>
        public List<string> AllowedActions { get; set; } = new List<string>();

        /// <summary>
        /// The refund percentage the traveler would receive if they cancelled this booking right now,
        /// from the global <c>RefundPolicyTiers</c> (shown before confirming a cancellation). Populated
        /// only on the detail read and only while the booking is cancellable; null otherwise.
        /// </summary>
        public int? CancellationRefundPercentage { get; set; }

        /// <summary>
        /// What actually came back to the traveler once the booking was cancelled: the KM sum of the
        /// <c>Refund</c> rows issued against this booking's payments. <c>0</c> is a real outcome (a 0% tier
        /// still writes the row), so this is only null when no refund was ever issued — nothing was charged,
        /// or a failed refund is still owed. Detail read (and the cancel response) only.
        /// </summary>
        public decimal? RefundedAmount { get; set; }

        /// <summary>The tier percentage that produced <see cref="RefundedAmount"/>; null on the same terms.</summary>
        public int? RefundedPercentage { get; set; }

        /// <summary>Small cover thumbnail (the tour's ordered-first destination) for list/detail cards.</summary>
        public byte[]? TourThumbnail { get; set; }
        public string? TourThumbnailContentType { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
