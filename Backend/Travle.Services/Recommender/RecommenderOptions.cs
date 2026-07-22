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
}
