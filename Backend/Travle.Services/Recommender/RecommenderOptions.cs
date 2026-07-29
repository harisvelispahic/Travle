namespace Travle.Services.Recommender
{
    /// <summary>
    /// The recommender's tunable parameters, bound from the <c>Recommender</c> config section. Chief
    /// among them is the <see cref="InteractionWeights"/> table — the "model" the recommender doc
    /// (04 §2) describes; keeping it here (one strongly-typed place, no scattered magic numbers) means
    /// every interaction-writing service reads one authoritative source. Defaults mirror 04 §2 exactly,
    /// so they stay valid even if the config section is absent, and must move in lockstep with
    /// <c>recommender-dokumentacija.md</c> (04 §6).
    /// </summary>
    public sealed class RecommenderOptions
    {
        public const string SectionName = "Recommender";

        public InteractionWeights Weights { get; set; } = new();

        /// <summary>Scoring formula constants (blend, recency, cold-start, cache TTLs) — the "model" (04 §3).</summary>
        public RecommenderScoringOptions Scoring { get; set; } = new();

        /// <summary>Upper bound on how many interests a user may pick during onboarding.</summary>
        public int MaxOnboardingSelections { get; set; } = 30;

        /// <summary>How many times the onboarding step is shown before giving up and marking the user
        /// onboarded (the per-display prompt cap). Overridable via the <c>Recommender</c> config section.</summary>
        public int MaxOnboardingPrompts { get; set; } = 3;
    }

    /// <summary>Weight of each recorded signal (04 §2). Stronger intent = higher weight.</summary>
    public sealed class InteractionWeights
    {
        public double BookingCompleted { get; set; } = 5;
        public double BookingConfirmed { get; set; } = 4;
        public double Favorite { get; set; } = 3;
        public double ReviewHigh { get; set; } = 3;
        public double OnboardingInterest { get; set; } = 2;
        public double View { get; set; } = 1;
        public double Search { get; set; } = 1;
    }

    /// <summary>
    /// Scoring formula constants (04 §3). Defaults are the documented values: the blend weights sum to 1,
    /// and the popularity sub-weights sum to 1. Any change here must move in lockstep with
    /// <c>recommender-dokumentacija.md</c> (04 §6).
    /// </summary>
    public sealed class RecommenderScoringOptions
    {
        /// <summary>Blend weight on the content (cosine) term (04 §3).</summary>
        public double ContentWeight { get; set; } = 0.8;
        /// <summary>Blend weight on the popularity term (04 §3).</summary>
        public double PopularityWeight { get; set; } = 0.2;
        /// <summary>Weight of average rating inside the popularity term (04 §3).</summary>
        public double RatingWeightInPopularity { get; set; } = 0.7;
        /// <summary>Weight of the (log) view count inside the popularity term (04 §3).</summary>
        public double ViewCountWeightInPopularity { get; set; } = 0.3;
        /// <summary>Multiplier applied to signals inside the recency window (04 §3).</summary>
        public double RecencyBoostMultiplier { get; set; } = 1.5;
        /// <summary>How recent (in days) a signal must be to earn the recency boost (04 §3).</summary>
        public int RecencyWindowDays { get; set; } = 30;
        /// <summary>Below this total weighted interaction score a user is cold-start ⇒ pure popularity (04 §3).</summary>
        public double ColdStartThreshold { get; set; } = 3;
        /// <summary>A candidate must exceed this content score to appear (0 ⇒ needs at least one shared feature).</summary>
        public double MinContentScore { get; set; } = 0;
        /// <summary>How many recommendations to return (04 §3, "top N = 10").</summary>
        public int TopN { get; set; } = 10;
        /// <summary>How many "similar destinations" to return (04 §3/§5, top-5).</summary>
        public int SimilarTopN { get; set; } = 5;
        /// <summary>Minutes to cache a user's computed recommendations (04 §4).</summary>
        public int ResultCacheMinutes { get; set; } = 15;
        /// <summary>Minutes to cache the approved-destination feature catalog (04 §4, hot data).</summary>
        public int CatalogCacheMinutes { get; set; } = 15;
    }
}
