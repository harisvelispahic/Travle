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
        Cancel = 3
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
        PasswordChanged = 23
    }

    /// <summary>
    /// Kind of recorded <see cref="UserInteraction"/> — recommender fuel. Weights are documented in
    /// docs/context/04-recommender-spec.md §2 and applied by the scoring service, not stored per row
    /// beyond the <see cref="UserInteraction.Weight"/> snapshot.
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
