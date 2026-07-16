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
        ScheduleCancelled = 15
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
