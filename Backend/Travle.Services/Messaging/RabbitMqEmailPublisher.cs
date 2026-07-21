using Travle.Model.Messaging;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using System.Text.Json;

namespace Travle.Services.Messaging
{
    public sealed class RabbitMqEmailPublisher : IEmailPublisher
    {
        private readonly RabbitMqConnection _connection;
        private readonly ILogger<RabbitMqEmailPublisher> _logger;

        public RabbitMqEmailPublisher(RabbitMqConnection connection, ILogger<RabbitMqEmailPublisher> logger)
        {
            _connection = connection;
            _logger = logger;
        }

        public Task PublishPasswordResetAsync(PasswordResetEmailMessage message, CancellationToken cancellationToken = default)
            => PublishAsync(MessagingConstants.EmailType.PasswordReset, message, cancellationToken);

        private async Task PublishAsync<T>(string type, T message, CancellationToken cancellationToken)
        {
            var connection = await _connection.GetConnectionAsync(cancellationToken);
            await using var channel = await connection.CreateChannelAsync(cancellationToken: cancellationToken);

            // Idempotent: ensures the durable queue exists whether the worker has started yet or not.
            await channel.QueueDeclareAsync(
                queue: MessagingConstants.EmailQueue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: cancellationToken);

            var body = JsonSerializer.SerializeToUtf8Bytes(message);
            var properties = new BasicProperties
            {
                Persistent = true,
                ContentType = "application/json",
                Headers = new Dictionary<string, object?> { [MessagingConstants.TypeHeader] = type }
            };

            await channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: MessagingConstants.EmailQueue,
                mandatory: false,
                basicProperties: properties,
                body: body,
                cancellationToken: cancellationToken);

            _logger.LogInformation("Published '{Type}' email message to queue '{Queue}'.", type, MessagingConstants.EmailQueue);
        }
    }
}
