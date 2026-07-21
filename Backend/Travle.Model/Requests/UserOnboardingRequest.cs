namespace Travle.Model.Requests
{
    /// <summary>
    /// The onboarding interest picks (04 §5). Both lists come from the DB (categories/tags); an empty
    /// request is a valid "skip". Written once as OnboardingInterest interactions to seed the
    /// recommender's cold start.
    /// </summary>
    public class UserOnboardingRequest
    {
        public List<int> CategoryIds { get; set; } = new();
        public List<int> TagIds { get; set; } = new();
    }
}
