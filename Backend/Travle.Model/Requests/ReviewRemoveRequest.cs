namespace Travle.Model.Requests
{
    /// <summary>
    /// An admin's moderation removal of a review (destination or tour). The <see cref="Reason"/> is
    /// mandatory — it is stored on the record (audit) and sent to the author in a notification. The review
    /// is soft-removed (<c>IsRemoved</c>), never hard-deleted.
    /// </summary>
    public class ReviewRemoveRequest
    {
        public string Reason { get; set; } = string.Empty;
    }
}
