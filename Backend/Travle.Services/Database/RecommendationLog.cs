namespace Travle.Services.Database
{
    /// <summary>
    /// Audit trail of a recommendation actually served to a user (score + explanation). Output-only:
    /// append-only and never an input to scoring. Nothing references it, so an optional retention
    /// purge (&gt;90 days) may run as a documented maintenance job.
    /// </summary>
    public class RecommendationLog : BaseEntity
    {
        public int UserId { get; set; }
        public User User { get; set; } = null!;

        public int DestinationId { get; set; }
        public Destination Destination { get; set; } = null!;

        public double Score { get; set; }
        public string Reason { get; set; } = string.Empty;
        public DateTime ServedAt { get; set; }
    }
}
