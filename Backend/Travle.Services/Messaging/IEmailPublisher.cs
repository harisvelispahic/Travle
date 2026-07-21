using Travle.Model.Messaging;

namespace Travle.Services.Messaging
{
    /// <summary>
    /// Publishes email requests onto RabbitMQ for the worker to send. The API never talks to SMTP —
    /// it only enqueues. Add a method per email kind as they arrive (booking confirmed, refund, …).
    /// </summary>
    public interface IEmailPublisher
    {
        Task PublishPasswordResetAsync(PasswordResetEmailMessage message, CancellationToken cancellationToken = default);
    }
}
