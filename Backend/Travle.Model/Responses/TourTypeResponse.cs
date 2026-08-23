namespace Travle.Model.Responses
{
    public class TourTypeResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// How many other records still reference this row. Zero means it can be deleted.
        /// </summary>
        public int UsageCount { get; set; }

        /// <summary>
        /// Why this row cannot be deleted, or <c>null</c> when it can. Lets a client render Delete
        /// <b>disabled with the reason shown</b> instead of only failing on click (course §6). The same
        /// sentence is what the service throws as a <c>ConflictException</c> if a delete is attempted
        /// anyway, so the two can never drift.
        /// </summary>
        public string? DeleteBlockedReason { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime? ModifiedAt { get; set; }
    }
}
