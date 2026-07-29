using Travle.Model.Responses;

namespace Travle.Services
{
    /// <summary>
    /// The recommender's read surface (04 §5): the current user's personalized, explained recommendations
    /// and a destination's "similar destinations". Interactions are recorded server-side by other services
    /// (details/search/favorites/booking state machine/review/onboarding); this service only reads them.
    /// </summary>
    public interface IRecommendationService
    {
        /// <summary>Top-N recommendations for the current (JWT) user, with reasons; appends RecommendationLogs.</summary>
        Task<RecommendationResponse> GetForCurrentUserAsync();

        /// <summary>Top-N destinations similar to the given one (item-to-item; no user profile, no logging).</summary>
        Task<List<RecommendationItem>> GetSimilarAsync(int destinationId);
    }
}
