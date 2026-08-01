using Travle.Services.Database;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// The single entry point every service uses to raise a user-facing notification (CLAUDE.md rule 8),
    /// replacing the pre-Phase-9 ad-hoc <c>_dbContext.Notifications.Add(...)</c> helpers.
    ///
    /// <para><see cref="Enqueue"/> stages the in-app row on the current <c>DbContext</c> (unsaved, so it
    /// commits inside the caller's transaction alongside the event that caused it) and buffers a pending
    /// live push. It never pushes or emails on its own.</para>
    ///
    /// <para><see cref="FlushAsync"/> runs <b>after</b> that transaction has committed — from the global
    /// action filter for HTTP flows, or explicitly from a background worker — and only then delivers the
    /// SignalR push (and, where flagged, the RabbitMQ email). See docs/notifications-and-signalr.md §3.</para>
    /// </summary>
    public interface INotificationDispatcher
    {
        /// <summary>
        /// Stage an in-app notification for <paramref name="userId"/>. Set <paramref name="alsoEmail"/> to
        /// additionally enqueue a worker email once the transaction commits. Leaves the row unsaved for the
        /// caller's <c>SaveChangesAsync</c>.
        /// </summary>
        void Enqueue(int userId, NotificationType type, string title, string text,
            int? relatedEntityId = null, bool alsoEmail = false);

        /// <summary>
        /// Deliver every notification staged since the last flush (best-effort SignalR push + email for the
        /// flagged subset), then clear the buffer. A no-op when nothing was staged. Call after the commit.
        /// </summary>
        Task FlushAsync(CancellationToken cancellationToken = default);
    }
}
