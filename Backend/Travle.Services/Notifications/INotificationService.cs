using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// Read/manage side of notifications for the current user (the JWT user — never a client-supplied id).
    /// The write side (raising notifications from events) is <see cref="INotificationDispatcher"/>.
    /// </summary>
    public interface INotificationService
    {
        /// <summary>The current user's notifications, newest first, paginated; filterable by read state/type.</summary>
        Task<PageResult<NotificationResponse>> GetMineAsync(NotificationSearch? search);

        /// <summary>The current user's unread count (bell badge).</summary>
        Task<int> GetUnreadCountAsync();

        /// <summary>Mark one of the current user's notifications read (idempotent); 404 if it isn't theirs.</summary>
        Task<NotificationResponse> MarkReadAsync(int id);

        /// <summary>Mark all of the current user's unread notifications read.</summary>
        Task MarkAllReadAsync();
    }
}
