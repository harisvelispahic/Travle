namespace Travle.Model.Messaging
{
    /// <summary>
    /// Shared names for the messaging contract between the API (publisher) and worker (consumer).
    /// All outbound emails share one durable queue; the <c>type</c> header discriminates the payload
    /// so the worker can dispatch to the right renderer. New email kinds add a value here + a case
    /// in the consumer — the queue and plumbing stay the same.
    /// </summary>
    public static class MessagingConstants
    {
        /// <summary>The single durable queue every email message is published to.</summary>
        public const string EmailQueue = "travle.emails";

        /// <summary>AMQP header key carrying the <see cref="EmailType"/> discriminator.</summary>
        public const string TypeHeader = "type";

        public static class EmailType
        {
            public const string PasswordReset = "password-reset";
        }
    }
}
