namespace Travle.Model.SearchObjects
{
    /// <summary>Filters for the current user's notification list (the endpoint always scopes to the JWT user).</summary>
    public class NotificationSearch : BaseSearchObject
    {
        /// <summary>
        /// Free-text filter over a notification's title and body. A notification is the only record of
        /// several events (a refund, a rejection reason, a schedule cancellation), so being able to find one
        /// by what it said is how an admin gets back to it once it has fallen off the first page.
        /// </summary>
        public string? Text { get; set; }

        /// <summary>Filter by read state (drives the mobile "unread" tab); null = all.</summary>
        public bool? IsRead { get; set; }

        /// <summary>
        /// Filter by notification category — the int mirror of the entity <c>NotificationType</c> enum, so
        /// the Model layer stays free of a dependency on the enum in Travle.Services. Null = all.
        /// </summary>
        public int? Type { get; set; }
    }
}
