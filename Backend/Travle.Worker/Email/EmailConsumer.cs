using Travle.Model.Messaging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;

namespace Travle.Worker.Email
{
    /// <summary>
    /// Drains the shared <c>travle.emails</c> queue and sends each message via SMTP. One long-lived
    /// connection (course §A.1), manual ack so a crash mid-send redelivers, and per-message retry with
    /// exponential backoff (1→2→4→8s) before giving up loudly. Dispatch is by the <c>type</c> header,
    /// so new email kinds add a case without touching the plumbing.
    /// </summary>
    public sealed class EmailConsumer : BackgroundService
    {
        private const int MaxSendAttempts = 4; // 1s, 2s, 4s backoff between the 4 tries

        private readonly RabbitMqOptions _rabbit;
        private readonly IEmailSender _emailSender;
        private readonly ILogger<EmailConsumer> _logger;

        private IConnection? _connection;
        private IChannel? _channel;
        private CancellationToken _stoppingToken;

        public EmailConsumer(IOptions<RabbitMqOptions> rabbit, IEmailSender emailSender, ILogger<EmailConsumer> logger)
        {
            _rabbit = rabbit.Value;
            _emailSender = emailSender;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _stoppingToken = stoppingToken;

            _connection = await ConnectWithRetryAsync(stoppingToken);
            _channel = await _connection.CreateChannelAsync(cancellationToken: stoppingToken);

            await _channel.QueueDeclareAsync(
                queue: MessagingConstants.EmailQueue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                cancellationToken: stoppingToken);

            // Take a few at a time so one slow send doesn't hog a big batch.
            await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 5, global: false, cancellationToken: stoppingToken);

            var consumer = new AsyncEventingBasicConsumer(_channel);
            consumer.ReceivedAsync += OnMessageAsync;

            await _channel.BasicConsumeAsync(
                queue: MessagingConstants.EmailQueue,
                autoAck: false,
                consumer: consumer,
                cancellationToken: stoppingToken);

            _logger.LogInformation("Email consumer is listening on '{Queue}'.", MessagingConstants.EmailQueue);

            try
            {
                await Task.Delay(Timeout.Infinite, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                // Expected on graceful shutdown.
            }
        }

        private async Task<IConnection> ConnectWithRetryAsync(CancellationToken cancellationToken)
        {
            var factory = new ConnectionFactory
            {
                HostName = _rabbit.Host,
                Port = _rabbit.Port,
                UserName = _rabbit.Username,
                Password = _rabbit.Password
            };

            var delay = TimeSpan.FromSeconds(1);
            for (var attempt = 1; ; attempt++)
            {
                try
                {
                    return await factory.CreateConnectionAsync(cancellationToken);
                }
                catch (Exception ex) when (!cancellationToken.IsCancellationRequested)
                {
                    _logger.LogWarning(ex, "RabbitMQ not reachable (attempt {Attempt}); retrying in {Seconds}s.",
                        attempt, delay.TotalSeconds);
                    await Task.Delay(delay, cancellationToken);
                    delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 2, 30));
                }
            }
        }

        private async Task OnMessageAsync(object sender, BasicDeliverEventArgs eventArgs)
        {
            try
            {
                await DispatchWithRetryAsync(eventArgs);
                await _channel!.BasicAckAsync(eventArgs.DeliveryTag, multiple: false);
            }
            catch (Exception ex)
            {
                // Never die silently (course §A.1). Drop the poison message (no requeue) so it can't hot-loop.
                _logger.LogError(ex, "Giving up on an email message after {Attempts} attempts; nacking without requeue.", MaxSendAttempts);
                await _channel!.BasicNackAsync(eventArgs.DeliveryTag, multiple: false, requeue: false);
            }
        }

        private async Task DispatchWithRetryAsync(BasicDeliverEventArgs eventArgs)
        {
            var delay = TimeSpan.FromSeconds(1);
            for (var attempt = 1; ; attempt++)
            {
                try
                {
                    await DispatchAsync(eventArgs);
                    return;
                }
                catch (Exception ex) when (attempt < MaxSendAttempts)
                {
                    _logger.LogWarning(ex, "Email send attempt {Attempt}/{Max} failed; retrying in {Seconds}s.",
                        attempt, MaxSendAttempts, delay.TotalSeconds);
                    await Task.Delay(delay, _stoppingToken);
                    delay = TimeSpan.FromSeconds(delay.TotalSeconds * 2);
                }
            }
        }

        private async Task DispatchAsync(BasicDeliverEventArgs eventArgs)
        {
            var type = ReadTypeHeader(eventArgs);

            switch (type)
            {
                case MessagingConstants.EmailType.PasswordReset:
                    var message = JsonSerializer.Deserialize<PasswordResetEmailMessage>(eventArgs.Body.Span)
                        ?? throw new InvalidOperationException("Empty password-reset payload.");
                    await SendPasswordResetAsync(message);
                    break;

                default:
                    // Unknown type: don't retry, don't loop — log and let it be acked (dropped).
                    _logger.LogWarning("Received an email message with unknown type '{Type}'; discarding.", type);
                    break;
            }
        }

        private Task SendPasswordResetAsync(PasswordResetEmailMessage message)
        {
            var minutes = Math.Max(1, (int)Math.Round((message.ExpiresAtUtc - DateTime.UtcNow).TotalMinutes));
            var subject = "Your Travle password reset code";
            var body =
                $"Hello {message.ToName},\n\n" +
                $"Your Travle password reset code is: {message.Code}\n\n" +
                $"It expires in about {minutes} minute(s). If you didn't request a password reset, you can safely ignore this email.\n\n" +
                "— The Travle team";

            return _emailSender.SendAsync(message.ToEmail, message.ToName, subject, body, _stoppingToken);
        }

        private static string? ReadTypeHeader(BasicDeliverEventArgs eventArgs)
        {
            if (eventArgs.BasicProperties.Headers is { } headers
                && headers.TryGetValue(MessagingConstants.TypeHeader, out var value)
                && value is byte[] bytes)
            {
                return Encoding.UTF8.GetString(bytes);
            }
            return null;
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            await base.StopAsync(cancellationToken);

            if (_channel is not null)
            {
                await _channel.DisposeAsync();
            }
            if (_connection is not null)
            {
                await _connection.DisposeAsync();
            }
        }
    }
}
