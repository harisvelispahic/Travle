using System.ComponentModel.DataAnnotations;

namespace Travle.Model.Messaging
{
    /// <summary>
    /// RabbitMQ connection settings, bound from the <c>RabbitMq</c> section on both the API
    /// (publisher) and the worker (consumer). Values come from the <c>RABBITMQ_*</c> environment
    /// variables in compose; localhost defaults live in each app's appsettings for local runs.
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
