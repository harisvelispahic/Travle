namespace Travle.Model.Requests
{
    /// <summary>
    /// An admin's rejection of a pending destination. The <see cref="Reason"/> is mandatory — it is
    /// stored on the record (audit) and sent to the submitter in the rejection notification.
    /// </summary>
    public class DestinationRejectRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
