namespace Travle.Model.Messaging
{
    /// <summary>
    /// Data the worker needs to render and send the email leg of an in-app notification. One generic
    /// message covers every email-worthy event (booking confirmation, status changes, application results,
    /// refund confirmations, 24-hour reminders): the API picks the <see cref="Subject"/> per notification
    /// type and the worker renders a single template from <see cref="Title"/> + <see cref="Body"/>.
    /// Published under the <see cref="MessagingConstants.EmailType.Notification"/> type.
    /// </summary>
    public sealed record NotificationEmailMessage
    {
        public required string ToEmail { get; init; }
        public required string ToName { get; init; }
        public required string Subject { get; init; }
        public required string Title { get; init; }
        public required string Body { get; init; }
    }
}
