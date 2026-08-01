namespace Travle.Model.SearchObjects
{
    /// <summary>Filters for the current user's notification list (the endpoint always scopes to the JWT user).</summary>
    public class NotificationSearch : BaseSearchObject
    {
        /// <summary>Filter by read state (drives the mobile "unread" tab); null = all.</summary>
        public bool? IsRead { get; set; }

        /// <summary>
        /// Filter by notification category — the int mirror of the entity <c>NotificationType</c> enum, so
        /// the Model layer stays free of a dependency on the enum in Travle.Services. Null = all.
        /// </summary>
        public int? Type { get; set; }
    }
}
