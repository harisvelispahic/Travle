namespace Travle.Model.Messaging
{
    /// <summary>
    /// Data the worker needs to render and send a password-reset email. Carries the <b>plaintext</b>
    /// code (which lives only in the message and the email — the database stores only its hash).
    /// Published under the <see cref="MessagingConstants.EmailType.PasswordReset"/> type.
    /// </summary>
    public sealed record PasswordResetEmailMessage
    {
        public required string ToEmail { get; init; }
        public required string ToName { get; init; }
        public required string Code { get; init; }
        public required DateTime ExpiresAtUtc { get; init; }
    }
}
