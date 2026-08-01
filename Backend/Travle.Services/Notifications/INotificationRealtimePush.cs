using Travle.Model.Responses;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// Pushes a persisted notification to its recipient's live connection. Implemented in the web layer
    /// over SignalR (<c>Travle.WebAPI</c>); abstracted here so <see cref="INotificationDispatcher"/> in
    /// <c>Travle.Services</c> never references the hub type (which would invert the project dependency).
    /// The push is best-effort — the DB row is the source of truth, so a failed push is logged, not thrown.
    /// </summary>
    public interface INotificationRealtimePush
    {
        Task PushAsync(int userId, NotificationResponse notification, CancellationToken cancellationToken = default);
    }
}
