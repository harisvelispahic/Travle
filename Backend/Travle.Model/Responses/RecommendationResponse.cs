namespace Travle.Model.Responses
{
    /// <summary>
    /// The current user's personalized recommendations (04 §3). <see cref="IsColdStart"/> is true when the
    /// user has too little signal for content-based scoring and the list is a pure-popularity fallback,
    /// labeled as such for the UI. Each <see cref="RecommendationItem"/> carries a light destination card
    /// (thumbnail only, rule 12), its blended score, and a human-readable reason.
    /// </summary>
    public class RecommendationResponse
    {
        public List<RecommendationItem> Items { get; set; } = new();

        /// <summary>True when the list is the cold-start popularity fallback rather than content-based.</summary>
        public bool IsColdStart { get; set; }
    }

    /// <summary>One recommended destination: the light card DTO plus its score and explanation (04 §3).</summary>
    public class RecommendationItem
    {
        public DestinationResponse Destination { get; set; } = null!;

        /// <summary>The final blended score behind the ranking (content + popularity), surfaced for transparency.</summary>
        public double Score { get; set; }

        /// <summary>Human-readable "why" — e.g. "Because you're interested in Nature".</summary>
        public string Reason { get; set; } = string.Empty;
    }
}
