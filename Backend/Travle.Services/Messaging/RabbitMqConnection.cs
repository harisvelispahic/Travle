using Travle.Model.Messaging;
using Microsoft.Extensions.Options;
using RabbitMQ.Client;

namespace Travle.Services.Messaging
{
    /// <summary>
    /// Owns a single long-lived RabbitMQ connection for the whole process (course §A.1 — never a new
    /// connection per publish). Registered as a singleton; the connection is created lazily on first
    /// use and re-created if it has dropped. Channels are cheap and created per publish by callers.
    /// </summary>
    public sealed class RabbitMqConnection : IAsyncDisposable
    {
        private readonly RabbitMqOptions _options;
        private readonly SemaphoreSlim _gate = new(1, 1);
        private IConnection? _connection;

        public RabbitMqConnection(IOptions<RabbitMqOptions> options)
        {
            _options = options.Value;
        }

        public async Task<IConnection> GetConnectionAsync(CancellationToken cancellationToken = default)
        {
            if (_connection is { IsOpen: true })
            {
                return _connection;
            }

            await _gate.WaitAsync(cancellationToken);
            try
            {
                if (_connection is { IsOpen: true })
                {
                    return _connection;
                }

                if (_connection is not null)
                {
                    await _connection.DisposeAsync();
                    _connection = null;
                }

                var factory = new ConnectionFactory
                {
                    HostName = _options.Host,
                    Port = _options.Port,
                    UserName = _options.Username,
                    Password = _options.Password
                };

                _connection = await factory.CreateConnectionAsync(cancellationToken);
                return _connection;
            }
            finally
            {
                _gate.Release();
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (_connection is not null)
            {
                await _connection.DisposeAsync();
            }
            _gate.Dispose();
        }
    }
}
