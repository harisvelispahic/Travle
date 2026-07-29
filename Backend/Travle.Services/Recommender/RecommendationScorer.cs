namespace Travle.Services.Recommender
{
    /// <summary>
    /// The recommender's pure scoring core (no DB, no cache, deterministic) — the literal implementation of
    /// the documented formula (04 §3), which is the "model" itself (04 §4a). Content-based cosine over binary
    /// categorical feature vectors, blended with a popularity term; a pure-popularity path for cold start;
    /// item-to-item cosine for "similar". Every tunable comes from <see cref="RecommenderScoringOptions"/>,
    /// so the code and the documented weight/formula table move together.
    /// </summary>
    public static class RecommendationScorer
    {
        /// <summary>
        /// Builds the normalized (unit-length) weighted user profile (04 §3). Destination-linked signals
        /// expand to that destination's category/region/tags via <paramref name="catalogById"/> (a signal
        /// whose destination is not in the approved catalog — e.g. later rejected — is skipped); onboarding
        /// and search signals contribute their category/tag directly. Signals from within the last
        /// <see cref="RecommenderScoringOptions.RecencyWindowDays"/> days earn the recency multiplier.
        /// </summary>
        public static IReadOnlyDictionary<FeatureKey, double> BuildProfile(
            IEnumerable<InteractionSignal> signals,
            IReadOnlyDictionary<int, DestinationFeature> catalogById,
            RecommenderScoringOptions options,
            DateTime nowUtc)
        {
            var recencyCutoff = nowUtc.AddDays(-options.RecencyWindowDays);
            var profile = new Dictionary<FeatureKey, double>();

            foreach (var signal in signals)
            {
                var weight = signal.Weight
                    * (signal.CreatedAt >= recencyCutoff ? options.RecencyBoostMultiplier : 1d);

                if (signal.DestinationId is int destinationId)
                {
                    // Expand the destination into its features. A destination missing from the approved
                    // catalog contributes nothing (its taste evidence was retracted by moderation).
                    if (catalogById.TryGetValue(destinationId, out var feature))
                    {
                        foreach (var key in feature.Features())
                        {
                            Add(profile, key, weight);
                        }
                    }
                }
                else if (signal.CategoryId is int categoryId)
                {
                    Add(profile, new FeatureKey(FeatureKind.Category, categoryId), weight);
                }
                else if (signal.TagId is int tagId)
                {
                    Add(profile, new FeatureKey(FeatureKind.Tag, tagId), weight);
                }
            }

            Normalize(profile);
            return profile;
        }

        /// <summary>
        /// Content + popularity scoring of a warm user's candidates (04 §3): for each candidate,
        /// <c>ContentWeight·cosine(profile, vector) + PopularityWeight·popularity</c>; keeps only those whose
        /// content score clears <see cref="RecommenderScoringOptions.MinContentScore"/> (an item with no
        /// feature overlap cannot be explained), sorted by final score descending. The single strongest
        /// profile feature the candidate shares is returned as the explanation contributor.
        /// </summary>
        public static List<ScoredDestination> ScoreForProfile(
            IReadOnlyDictionary<FeatureKey, double> profile,
            IEnumerable<DestinationFeature> candidates,
            int maxViewCount,
            RecommenderScoringOptions options)
        {
            var scored = new List<ScoredDestination>();

            foreach (var candidate in candidates)
            {
                var (content, topContributor) = ContentScore(profile, candidate);
                if (content <= options.MinContentScore)
                {
                    continue;
                }

                var popularity = Popularity(candidate, maxViewCount, options);
                var final = options.ContentWeight * content + options.PopularityWeight * popularity;
                scored.Add(new ScoredDestination(candidate.Id, final, topContributor));
            }

            scored.Sort((a, b) => b.Score.CompareTo(a.Score));
            return scored;
        }

        /// <summary>Pure-popularity ranking for cold-start users (04 §3); a null contributor labels it as such.</summary>
        public static List<ScoredDestination> ScoreByPopularity(
            IEnumerable<DestinationFeature> candidates,
            int maxViewCount,
            RecommenderScoringOptions options)
        {
            var scored = candidates
                .Select(c => new ScoredDestination(c.Id, Popularity(c, maxViewCount, options), (FeatureKey?)null))
                .ToList();
            scored.Sort((a, b) => b.Score.CompareTo(a.Score));
            return scored;
        }

        /// <summary>
        /// Item-to-item cosine similarity between a target destination and candidates (04 §3, the second
        /// surface) — no user profile, so it works for brand-new users too. Returns matches with a positive
        /// overlap, sorted by similarity descending, each with the shared features for the explanation.
        /// </summary>
        public static List<SimilarScored> Similar(
            DestinationFeature target,
            IEnumerable<DestinationFeature> candidates,
            RecommenderScoringOptions options)
        {
            var targetFeatures = target.Features().ToHashSet();
            var targetNorm = Math.Sqrt(targetFeatures.Count);
            var results = new List<SimilarScored>();

            foreach (var candidate in candidates)
            {
                if (candidate.Id == target.Id)
                {
                    continue;
                }

                var candidateFeatures = candidate.Features().ToList();
                var shared = candidateFeatures.Where(targetFeatures.Contains).ToList();
                if (shared.Count == 0)
                {
                    continue;
                }

                var similarity = shared.Count / (targetNorm * Math.Sqrt(candidateFeatures.Count));
                results.Add(new SimilarScored(candidate.Id, similarity, shared));
            }

            results.Sort((a, b) => b.Score.CompareTo(a.Score));
            return results;
        }

        // Content cosine between the (already unit-length) profile and a candidate's binary vector, plus the
        // profile's single strongest feature among the candidate's features (the explanation contributor).
        // Because the profile is unit-length and the candidate vector is binary, cosine reduces to
        // (Σ profile[feature over the candidate's features]) / sqrt(featureCount).
        private static (double Score, FeatureKey? TopContributor) ContentScore(
            IReadOnlyDictionary<FeatureKey, double> profile,
            DestinationFeature candidate)
        {
            double dot = 0d;
            var count = 0;
            FeatureKey? top = null;
            var topWeight = 0d;

            foreach (var key in candidate.Features())
            {
                count++;
                if (profile.TryGetValue(key, out var w) && w > 0d)
                {
                    dot += w;
                    if (w > topWeight)
                    {
                        topWeight = w;
                        top = key;
                    }
                }
            }

            if (count == 0 || dot <= 0d)
            {
                return (0d, null);
            }

            return (dot / Math.Sqrt(count), top);
        }

        // Popularity term (04 §3): RatingWeight·(rating/5) + ViewCountWeight·(log(1+views)/log(1+maxViews));
        // the view sub-term is 0 when no candidate has any views (avoids 0/0).
        private static double Popularity(DestinationFeature candidate, int maxViewCount, RecommenderScoringOptions options)
        {
            var ratingTerm = candidate.AverageRating / 5d;
            var viewTerm = maxViewCount > 0
                ? Math.Log(1 + candidate.ViewCount) / Math.Log(1 + maxViewCount)
                : 0d;
            return options.RatingWeightInPopularity * ratingTerm + options.ViewCountWeightInPopularity * viewTerm;
        }

        private static void Add(Dictionary<FeatureKey, double> profile, FeatureKey key, double weight)
            => profile[key] = profile.TryGetValue(key, out var current) ? current + weight : weight;

        private static void Normalize(Dictionary<FeatureKey, double> profile)
        {
            var norm = Math.Sqrt(profile.Values.Sum(v => v * v));
            if (norm <= 0d)
            {
                return;
            }
            foreach (var key in profile.Keys.ToList())
            {
                profile[key] /= norm;
            }
        }
    }
}
