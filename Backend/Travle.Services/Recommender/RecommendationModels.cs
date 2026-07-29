namespace Travle.Services.Recommender
{
    /// <summary>The kind of feature-space dimension (04 §3: one dimension per category, tag and region).</summary>
    public enum FeatureKind
    {
        Category,
        Tag,
        Region
    }

    /// <summary>A single feature-space dimension: its kind and the reference-entity id it stands for.</summary>
    public readonly record struct FeatureKey(FeatureKind Kind, int Id);

    /// <summary>
    /// A destination reduced to exactly what scoring needs: its feature dimensions (one category, one
    /// region, its tags) and popularity inputs (04 §3). This is the shape cached as the "catalog" — small
    /// and image-free, so caching the whole approved catalogue is cheap.
    /// </summary>
    public sealed record DestinationFeature(
        int Id,
        int CategoryId,
        int RegionId,
        IReadOnlyList<int> TagIds,
        double AverageRating,
        int ViewCount)
    {
        /// <summary>The destination's binary feature set: its one category, its one region, and each tag.</summary>
        public IEnumerable<FeatureKey> Features()
        {
            yield return new FeatureKey(FeatureKind.Category, CategoryId);
            yield return new FeatureKey(FeatureKind.Region, RegionId);
            foreach (var tagId in TagIds)
            {
                yield return new FeatureKey(FeatureKind.Tag, tagId);
            }
        }
    }

    /// <summary>A recorded interaction reduced to what profile-building needs (04 §2/§3).</summary>
    public sealed record InteractionSignal(
        double Weight,
        DateTime CreatedAt,
        int? DestinationId,
        int? CategoryId,
        int? TagId);

    /// <summary>
    /// A scored candidate from <see cref="RecommendationScorer"/>: the destination id, the final blended
    /// score, and the single top feature contributor for the explanation (null ⇒ pure popularity, i.e. a
    /// cold-start list where there is no content basis to explain).
    /// </summary>
    public sealed record ScoredDestination(int DestinationId, double Score, FeatureKey? TopContributor);

    /// <summary>An item-to-item similarity match plus the features it shares with the target (for the reason).</summary>
    public sealed record SimilarScored(int DestinationId, double Score, IReadOnlyList<FeatureKey> SharedFeatures);
}
