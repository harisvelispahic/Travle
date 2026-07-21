namespace Travle.Worker.Email
{
    /// <summary>Sends a single email. The rendered subject/body come from the consumer.</summary>
    public interface IEmailSender
    {
        Task SendAsync(string toEmail, string toName, string subject, string body, CancellationToken cancellationToken);
    }
}
