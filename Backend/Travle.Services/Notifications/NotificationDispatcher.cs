using Travle.Model.Messaging;
using Travle.Services.Database;
using Travle.Services.Messaging;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Travle.Services.Notifications
{
    /// <summary>
    /// Scoped, in-memory "outbox": <see cref="Enqueue"/> stages notification rows on the request's
    /// <c>DbContext</c> and remembers them; <see cref="FlushAsync"/> — called once the caller's transaction
    /// has committed — pushes each committed row over SignalR and enqueues the email for the flagged subset.
    /// Best-effort by design: the row is the durable source of truth, so a push/email failure is logged, not
    /// propagated (it must never turn a committed action into a 500). See docs/notifications-and-signalr.md.
    /// </summary>
    public sealed class NotificationDispatcher : INotificationDispatcher
    {
        private readonly TravleDbContext _dbContext;
        private readonly INotificationRealtimePush _push;
        private readonly IEmailPublisher _emailPublisher;
        private readonly ILogger<NotificationDispatcher> _logger;

        private readonly List<Pending> _pending = new();

        private sealed record Pending(Notification Entity, bool Email);

        public NotificationDispatcher(
            TravleDbContext dbContext,
            INotificationRealtimePush push,
            IEmailPublisher emailPublisher,
            ILogger<NotificationDispatcher> logger)
        {
            _dbContext = dbContext;
            _push = push;
            _emailPublisher = emailPublisher;
            _logger = logger;
        }

        public void Enqueue(int userId, NotificationType type, string title, string text,
            int? relatedEntityId = null, bool alsoEmail = false)
        {
            var notification = new Notification
            {
                UserId = userId,
                Type = type,
                Title = title,
                Text = text,
                RelatedEntityId = relatedEntityId,
                IsRead = false
            };

            _dbContext.Notifications.Add(notification);
            _pending.Add(new Pending(notification, alsoEmail));
        }

        public async Task FlushAsync(CancellationToken cancellationToken = default)
        {
            if (_pending.Count == 0)
            {
                return;
            }

            // Snapshot + clear before dispatching so a re-entrant flush (or a second SaveChanges in the same
            // request) never double-sends. Only rows that actually persisted (Id assigned by SaveChanges) are
            // dispatched — a staged-but-never-saved row (Id == 0) is skipped defensively.
            var batch = _pending.Where(p => p.Entity.Id != 0).ToList();
            var unsaved = _pending.Count - batch.Count;
            _pending.Clear();

            if (unsaved > 0)
            {
                _logger.LogWarning("{Count} staged notification(s) were never saved before flush; skipping their push.", unsaved);
            }
            if (batch.Count == 0)
            {
                return;
            }

            foreach (var pending in batch)
            {
                try
                {
                    await _push.PushAsync(pending.Entity.UserId, NotificationMapper.ToResponse(pending.Entity), cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to push notification {NotificationId} to user {UserId}.",
                        pending.Entity.Id, pending.Entity.UserId);
                }
            }

            await PublishEmailsAsync(batch, cancellationToken);
        }

        // Emails the flagged subset. One query resolves every recipient's address, then one durable message
        // per recipient — no N+1, and a broker hiccup is logged rather than thrown.
        private async Task PublishEmailsAsync(List<Pending> batch, CancellationToken cancellationToken)
        {
            var emailItems = batch.Where(p => p.Email).ToList();
            if (emailItems.Count == 0)
            {
                return;
            }

            var recipientIds = emailItems.Select(p => p.Entity.UserId).Distinct().ToList();
            var recipients = await _dbContext.Users
                .AsNoTracking()
                .Where(u => recipientIds.Contains(u.Id))
                .Select(u => new { u.Id, u.Email, u.FirstName, u.LastName })
                .ToDictionaryAsync(u => u.Id, cancellationToken);

            foreach (var pending in emailItems)
            {
                if (!recipients.TryGetValue(pending.Entity.UserId, out var recipient)
                    || string.IsNullOrWhiteSpace(recipient.Email))
                {
                    continue;
                }

                var message = new NotificationEmailMessage
                {
                    ToEmail = recipient.Email,
                    ToName = $"{recipient.FirstName} {recipient.LastName}".Trim(),
                    Subject = $"Travle — {pending.Entity.Title}",
                    Title = pending.Entity.Title,
                    Body = pending.Entity.Text
                };

                try
                {
                    await _emailPublisher.PublishNotificationAsync(message, cancellationToken);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to enqueue notification email for user {UserId}.", pending.Entity.UserId);
                }
            }
        }
    }
}
