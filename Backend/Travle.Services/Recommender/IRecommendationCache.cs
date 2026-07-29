using Travle.Model.Responses;

namespace Travle.Services.Recommender
{
    /// <summary>
    /// Owns the recommender's two <c>IMemoryCache</c> entries (04 §4): the per-user computed result (short
    /// TTL, explicitly invalidated on strong interactions) and the shared approved-destination feature
    /// catalog (hot, rarely-changing data on a plain TTL). Interaction-writing services depend only on
    /// <see cref="InvalidateUser"/>; the recommendation service uses the rest.
    /// </summary>
    public interface IRecommendationCache
    {
        /// <summary>Returns a cached recommendation result for the user, if one is still live.</summary>
        bool TryGetUserResult(int userId, out RecommendationResponse result);

        /// <summary>Caches a freshly computed recommendation result for the user (TTL from options).</summary>
        void SetUserResult(int userId, RecommendationResponse result);

        /// <summary>Drops the user's cached result so the next request recomputes (call on strong interactions).</summary>
        void InvalidateUser(int userId);

        /// <summary>Returns the approved-destination feature catalog, loading and caching it on a miss.</summary>
        Task<IReadOnlyList<DestinationFeature>> GetOrLoadCatalogAsync(Func<Task<IReadOnlyList<DestinationFeature>>> loader);
    }
}
