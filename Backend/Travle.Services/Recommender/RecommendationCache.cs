using Travle.Model.Responses;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace Travle.Services.Recommender
{
    /// <summary>
    /// <see cref="IRecommendationCache"/> over <c>IMemoryCache</c>. Singleton: it holds no per-request state,
    /// only the shared cache handle and the (bound-once) TTLs. The per-user result key is invalidated
    /// explicitly on strong interactions; the catalog key rides a plain absolute expiration because it is
    /// hot, rarely-changing data (04 §4).
    /// </summary>
    public sealed class RecommendationCache : IRecommendationCache
    {
        private const string CatalogKey = "recommender:catalog";
        private static string UserKey(int userId) => $"recommender:user:{userId}";

        private readonly IMemoryCache _cache;
        private readonly RecommenderScoringOptions _options;

        public RecommendationCache(IMemoryCache cache, IOptions<RecommenderOptions> options)
        {
            _cache = cache;
            _options = options.Value.Scoring;
        }

        public bool TryGetUserResult(int userId, out RecommendationResponse result)
            => _cache.TryGetValue(UserKey(userId), out result!);

        public void SetUserResult(int userId, RecommendationResponse result)
            => _cache.Set(UserKey(userId), result, TimeSpan.FromMinutes(_options.ResultCacheMinutes));

        public void InvalidateUser(int userId) => _cache.Remove(UserKey(userId));

        public async Task<IReadOnlyList<DestinationFeature>> GetOrLoadCatalogAsync(
            Func<Task<IReadOnlyList<DestinationFeature>>> loader)
            => await _cache.GetOrCreateAsync(CatalogKey, async entry =>
            {
                entry.AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(_options.CatalogCacheMinutes);
                return await loader();
            }) ?? Array.Empty<DestinationFeature>();
    }
}
