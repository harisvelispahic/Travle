namespace Travle.Model.Responses
{
    /// <summary>
    /// An in-app notification for the current user. The same shape is returned by the REST list/mark
    /// endpoints and pushed live over SignalR, so the client renders both identically.
    /// </summary>
    public class NotificationResponse
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public string Title { get; set; } = string.Empty;
        public string Text { get; set; } = string.Empty;

        /// <summary>
        /// The <c>NotificationType</c> enum name (e.g. "BookingConfirmed") — never the raw int; drives the
        /// client's icon/grouping.
        /// </summary>
        public string Type { get; set; } = string.Empty;

        /// <summary>Optional deep-link target (e.g. the booking id), interpreted per <see cref="Type"/>.</summary>
        public int? RelatedEntityId { get; set; }

        public bool IsRead { get; set; }
        public DateTime? ReadAt { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
