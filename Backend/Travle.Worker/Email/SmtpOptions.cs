namespace Travle.Worker.Email
{
    /// <summary>
    /// SMTP settings, bound from the <c>Smtp</c> section (values from the <c>SMTP_*</c> env vars in
    /// compose). Only the worker holds these — the API never sends mail. Not validated on startup so
    /// the worker still comes up (and drains the queue) when SMTP isn't configured yet; the sender
    /// logs and skips in that case.
    /// </summary>
    public sealed class SmtpOptions
    {
        public const string SectionName = "Smtp";

        public string Host { get; set; } = string.Empty;
        public int Port { get; set; } = 587;
        public string? Username { get; set; }
        public string? Password { get; set; }
        public string From { get; set; } = "no-reply@travle.com";
        public string FromName { get; set; } = "Travle";

        /// <summary>STARTTLS (587/2525, e.g. Mailtrap) when true; implicit TLS (465) when false.</summary>
        public bool UseStartTls { get; set; } = true;
    }
}
