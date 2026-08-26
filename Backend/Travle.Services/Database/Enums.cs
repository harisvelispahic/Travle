namespace Travle.Services.Database
{
    /// <summary>Moderation lifecycle of a submitted <see cref="Destination"/>.</summary>
    public enum DestinationStatus
    {
        Pending = 0,
        Approved = 1,
        Rejected = 2
    }

    /// <summary>Lifecycle of a single <see cref="TourSchedule"/> slot.</summary>
    public enum ScheduleStatus
    {
        Active = 0,
        Cancelled = 1
    }

    /// <summary>
    /// The booking lifecycle states, driven only by the centralized <c>BookingStateMachine</c>. The
    /// integer values are a hard contract: they equal the seeded <see cref="BookingStatus"/> reference
    /// row Ids, so <c>(int)BookingStatusCode.Confirmed == Booking.StatusId</c> and the filtered unique
    /// index on <see cref="Booking"/> (<c>WHERE StatusId IN (1,2,3)</c>) stays correct. This enum is the
    /// type-safe discriminator the state factory switches on — never persisted as a separate column and
    /// never renumbered.
    /// </summary>
    public enum BookingStatusCode
    {
        PaymentInProgress = 1,
        Pending = 2,
        Confirmed = 3,
        Completed = 4,
        Cancelled = 5,
        Expired = 6
    }

    /// <summary>
    /// A transition a booking currently permits. Each <c>BookingState</c> reports its own allowed set so
    /// the UI can render exactly the buttons that will succeed (rule K "disabled with reason"). Serialized
    /// to the client as the enum name, never acted on by matching a raw int.
    /// </summary>
    public enum BookingAction
    {
        /// <summary>Traveler pays for a held booking (PaymentInProgress → Pending, via Stripe in Phase 6).</summary>
        Pay = 0,
        /// <summary>Organizer confirms a paid booking (Pending → Confirmed).</summary>
        Confirm = 1,
        /// <summary>Organizer rejects a paid booking with a reason (Pending → Cancelled, 100% refund).</summary>
        Reject = 2,
        /// <summary>Traveler cancels their own booking (Pending/Confirmed → Cancelled, tiered refund).</summary>
        Cancel = 3,
        /// <summary>
        /// Organizer calls off a single confirmed booking with a reason (Confirmed → Cancelled, 100% refund).
        /// Distinct from <see cref="Cancel"/> so the desktop can gate the organizer's button on the state
        /// machine rather than on a hardcoded status name; a Pending booking uses <see cref="Reject"/> instead.
        /// </summary>
        CancelByOrganizer = 4
    }

    /// <summary>Decision lifecycle of a <see cref="RoleApplication"/>.</summary>
    public enum RoleApplicationStatus
    {
        Pending = 0,
        Approved = 1,
        Rejected = 2
    }

    /// <summary>State of a Stripe-backed <see cref="Payment"/>.</summary>
    public enum PaymentStatus
    {
        Pending = 0,
        Succeeded = 1,
        Failed = 2,
        Refunded = 3,
        PartiallyRefunded = 4
    }

    /// <summary>Category of an in-app <see cref="Notification"/>; drives the UI icon/grouping.</summary>
    public enum NotificationType
    {
        General = 0,
        BookingConfirmed = 1,
        BookingRejected = 2,
        BookingCancelled = 3,
        BookingExpired = 4,
        BookingReminder = 5,
        BookingCompleted = 6,
        PaymentSucceeded = 7,
        RefundIssued = 8,
        DestinationApproved = 9,
        DestinationRejected = 10,
        RoleApplicationApproved = 11,
        RoleApplicationRejected = 12,
        ReviewReceived = 13,
        AccountSuspended = 14,
        ScheduleCancelled = 15,
        ReviewRemoved = 16,

        /// <summary>Organizer: a traveler's payment cleared and a booking now awaits their confirmation.</summary>
        BookingPlaced = 17,

        /// <summary>Admin: a user submitted a Curator/Organizer role application for review.</summary>
        RoleApplicationSubmitted = 18,

        /// <summary>Admin: a destination was submitted (or edited back to Pending) and needs moderation.</summary>
        DestinationSubmitted = 19,

        /// <summary>A user whose account was created for them by an admin (welcome / first sign-in prompt).</summary>
        AccountCreated = 20,

        /// <summary>A user who was granted a role directly by an admin (outside the application flow).</summary>
        RoleGranted = 21,

        /// <summary>A user who had a role removed by an admin.</summary>
        RoleRevoked = 22,

        /// <summary>
        /// The user's password was changed or reset. Session-affecting: every session is invalidated
        /// server-side (stamp rolled + refresh tokens dropped), and this notification drives the client's
        /// immediate force-logout on all connected devices (same mechanism as <see cref="AccountSuspended"/>).
        /// </summary>
        PasswordChanged = 23,

        /// <summary>
        /// Organizer: a destination one of their tours visits left the published catalogue (its curator/an
        /// admin edited it back to Pending, so it awaits re-moderation) and is no longer bookable-ready.
        /// </summary>
        DestinationUnavailable = 24,

        /// <summary>
        /// Organizer: a previously-unavailable destination one of their tours visits was re-approved and is
        /// published again — the tour's itinerary is whole once more.
        /// </summary>
        DestinationAvailable = 25,

        /// <summary>A user whose suspension was lifted by an admin (they can sign in again).</summary>
        AccountReinstated = 26,

        /// <summary>Curator: one of their destinations was featured on the platform by an admin.</summary>
        DestinationFeatured = 27,

        /// <summary>
        /// Traveler/curator: a tour they have an upcoming booking on (or one they favorited) changed — the
        /// organizer edited its itinerary/name, or added a new date.
        /// </summary>
        TourUpdated = 28,

        /// <summary>
        /// Admin: an automatic refund failed on Stripe and is owed to a traveler; it needs a manual retry
        /// from the payments screen.
        /// </summary>
        RefundFailed = 29,

        /// <summary>
        /// Traveler: a card was declined, so that payment attempt failed. The booking itself survives —
        /// the seats stay held for the rest of the 15-minute window so another card can be tried.
        /// </summary>
        PaymentFailed = 30
    }

    /// <summary>
    /// Kind of recorded <see cref="UserInteraction"/> — recommender fuel. Weights are applied by the
    /// scoring service, not stored per row beyond the <see cref="UserInteraction.Weight"/> snapshot.
    /// </summary>
    public enum InteractionType
    {
        View = 0,
        Search = 1,
        Favorite = 2,
        BookingConfirmed = 3,
        BookingCompleted = 4,
        ReviewHigh = 5,
        OnboardingInterest = 6
    }
}
