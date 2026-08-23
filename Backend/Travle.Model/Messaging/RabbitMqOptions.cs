using System.ComponentModel.DataAnnotations;

namespace Travle.Model.Messaging
{
    /// <summary>
    /// RabbitMQ connection settings, bound from the <c>RabbitMq</c> section on both the API
    /// (publisher) and the worker (consumer). Every value comes from <c>.env</c> — compose injects the
    /// <c>RabbitMq__*</c> names into each container, and a local <c>dotnet run</c> gets them through
    /// <c>EnvironmentConfigurationAliases</c> (host excepted: it differs per host, so <c>.env</c> carries
    /// an explicit <c>RabbitMq__Host=localhost</c> override). Nothing infrastructural is kept in
    /// appsettings.json (course §3.3); the property initialisers below are only a last-resort fallback so
    /// a misconfigured run fails on connect with a clear log rather than at bind time.
    /// </summary>
    public sealed class RabbitMqOptions
    {
        public const string SectionName = "RabbitMq";

        [Required] public string Host { get; set; } = "localhost";
        [Range(1, 65535)] public int Port { get; set; } = 5672;
        [Required] public string Username { get; set; } = "guest";
        [Required] public string Password { get; set; } = "guest";
    }
}
