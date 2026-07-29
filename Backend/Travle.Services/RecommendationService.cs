using Travle.Model.Exceptions;
using Travle.Model.Responses;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Projections;
using Travle.Services.Recommender;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Travle.Services
{
    /// <summary>
    /// Computes recommendations on demand (04 §4, Option A + slim C): loads the user's interactions and the
    /// cached approved-destination feature catalog, builds the weighted profile, scores, and returns the
    /// top-N with explanations — caching the per-user result and appending every served item to
    /// RecommendationLogs (a pure audit trail, never an input). A cold-start user (too little signal) gets a
    /// labeled pure-popularity list. The scoring math lives in <see cref="RecommendationScorer"/>; this
    /// service is orchestration only, so the documented formula and the code stay one-to-one.
    /// </summary>
    public class RecommendationService : IRecommendationService
    {
        private const string PopularReason = "Popular right now — highly rated by other travelers";

        private readonly TravleDbContext _dbContext;
        private readonly IAppAuthorizationService _authorization;
        private readonly IRecommendationCache _cache;
        private readonly RecommenderScoringOptions _options;

        public RecommendationService(
            TravleDbContext dbContext,
            IAppAuthorizationService authorization,
            IRecommendationCache cache,
            IOptions<RecommenderOptions> options)
        {
            _dbContext = dbContext;
            _authorization = authorization;
            _cache = cache;
            _options = options.Value.Scoring;
        }

        public async Task<RecommendationResponse> GetForCurrentUserAsync()
        {
            var userId = _authorization.RequireUserId();

            // Repeated identical requests inside the window are served from cache without recomputation
            // (and, deliberately, without re-logging — logs record distinct computations, not every serve).
            if (_cache.TryGetUserResult(userId, out var cachedResult))
            {
                return cachedResult;
            }

            var catalog = await _cache.GetOrLoadCatalogAsync(LoadApprovedCatalogAsync);
            var catalogById = catalog.ToDictionary(c => c.Id);
            var maxViewCount = catalog.Count > 0 ? catalog.Max(c => c.ViewCount) : 0;

            var signals = await LoadSignalsAsync(userId);
            var completedDestinationIds = await LoadCompletedDestinationIdsAsync(userId);

            // Candidates: every approved destination the user has not already completed. Favorited ones stay
            // eligible on purpose (a saved-and-forgotten destination should still resurface) — decision 04 §.
            var candidates = catalog.Where(c => !completedDestinationIds.Contains(c.Id)).ToList();

            var totalWeight = signals.Sum(s => s.Weight);
            var isColdStart = totalWeight < _options.ColdStartThreshold;

            List<ScoredDestination> ranked;
            if (isColdStart)
            {
                ranked = RecommendationScorer.ScoreByPopularity(candidates, maxViewCount, _options);
            }
            else
            {
                var profile = RecommendationScorer.BuildProfile(signals, catalogById, _options, DateTime.UtcNow);
                ranked = RecommendationScorer.ScoreForProfile(profile, candidates, maxViewCount, _options);
            }

            var top = ranked.Take(_options.TopN).ToList();
            var result = await BuildResponseAsync(top, isColdStart, userId);

            await AppendLogsAsync(userId, result.Items);
            _cache.SetUserResult(userId, result);
            return result;
        }

        public async Task<List<RecommendationItem>> GetSimilarAsync(int destinationId)
        {
            var userId = _authorization.RequireUserId();

            var target = await LoadFeatureAsync(destinationId)
                ?? throw new NotFoundException("Destination", destinationId);

            var catalog = await _cache.GetOrLoadCatalogAsync(LoadApprovedCatalogAsync);
            var matches = RecommendationScorer.Similar(target, catalog, _options)
                .Take(_options.SimilarTopN)
                .ToList();
            if (matches.Count == 0)
            {
                return new List<RecommendationItem>();
            }

            var cardsById = await LoadCardsAsync(matches.Select(m => m.DestinationId).ToList(), userId);
            var names = await LoadFeatureNamesAsync(matches.SelectMany(m => m.SharedFeatures).ToList());

            var items = new List<RecommendationItem>();
            foreach (var match in matches)
            {
                if (cardsById.TryGetValue(match.DestinationId, out var card))
                {
                    items.Add(new RecommendationItem
                    {
                        Destination = card,
                        Score = match.Score,
                        Reason = SimilarReason(match.SharedFeatures, names)
                    });
                }
            }
            return items;
        }

        // --- assembly --------------------------------------------------------------------------------

        private async Task<RecommendationResponse> BuildResponseAsync(
            IReadOnlyList<ScoredDestination> ranked, bool isColdStart, int userId)
        {
            var cardsById = await LoadCardsAsync(ranked.Select(r => r.DestinationId).ToList(), userId);
            var contributorKeys = ranked
                .Where(r => r.TopContributor.HasValue)
                .Select(r => r.TopContributor!.Value)
                .ToList();
            var names = await LoadFeatureNamesAsync(contributorKeys);

            var items = new List<RecommendationItem>();
            foreach (var scored in ranked)
            {
                if (cardsById.TryGetValue(scored.DestinationId, out var card))
                {
                    items.Add(new RecommendationItem
                    {
                        Destination = card,
                        Score = scored.Score,
                        Reason = ProfileReason(scored.TopContributor, names)
                    });
                }
            }

            return new RecommendationResponse { Items = items, IsColdStart = isColdStart };
        }

        private static string ProfileReason(FeatureKey? contributor, FeatureNames names)
        {
            if (contributor is not FeatureKey key)
            {
                return PopularReason;
            }
            return key.Kind switch
            {
                FeatureKind.Category => $"Because you're interested in {names.Category(key.Id)}",
                FeatureKind.Tag => $"Shares a tag you like: {names.Tag(key.Id)}",
                FeatureKind.Region => $"In {names.Region(key.Id)}, a region you explore",
                _ => PopularReason
            };
        }

        private static string SimilarReason(IReadOnlyList<FeatureKey> shared, FeatureNames names)
        {
            var categoryId = shared.Where(f => f.Kind == FeatureKind.Category).Select(f => (int?)f.Id).FirstOrDefault();
            var regionId = shared.Where(f => f.Kind == FeatureKind.Region).Select(f => (int?)f.Id).FirstOrDefault();
            var tagId = shared.Where(f => f.Kind == FeatureKind.Tag).Select(f => (int?)f.Id).FirstOrDefault();

            if (categoryId is int cat && regionId is int reg)
            {
                return $"Also a {names.Category(cat)} in {names.Region(reg)}";
            }
            if (categoryId is int c)
            {
                return $"Also a {names.Category(c)}";
            }
            if (regionId is int r)
            {
                return $"Also in {names.Region(r)}";
            }
            if (tagId is int t)
            {
                return $"Shares the {names.Tag(t)} theme";
            }
            return "Similar destination";
        }

        // --- data loads ------------------------------------------------------------------------------

        // The approved-destination feature catalog (cached). Materialize the tag-id subquery to a list in
        // memory rather than projecting into the record constructor directly, keeping the SQL translation
        // simple and predictable.
        private async Task<IReadOnlyList<DestinationFeature>> LoadApprovedCatalogAsync()
        {
            var rows = await _dbContext.Destinations.AsNoTracking()
                .Where(d => d.Status == DestinationStatus.Approved)
                .Select(d => new
                {
                    d.Id,
                    d.CategoryId,
                    RegionId = d.City.RegionId,
                    TagIds = d.DestinationTags.Select(dt => dt.TagId).ToList(),
                    d.AverageRating,
                    d.ViewCount
                })
                .ToListAsync();

            return rows
                .Select(r => new DestinationFeature(r.Id, r.CategoryId, r.RegionId, r.TagIds, r.AverageRating, r.ViewCount))
                .ToList();
        }

        private async Task<DestinationFeature?> LoadFeatureAsync(int destinationId)
        {
            var row = await _dbContext.Destinations.AsNoTracking()
                .Where(d => d.Id == destinationId)
                .Select(d => new
                {
                    d.Id,
                    d.CategoryId,
                    RegionId = d.City.RegionId,
                    TagIds = d.DestinationTags.Select(dt => dt.TagId).ToList(),
                    d.AverageRating,
                    d.ViewCount
                })
                .FirstOrDefaultAsync();

            return row is null
                ? null
                : new DestinationFeature(row.Id, row.CategoryId, row.RegionId, row.TagIds, row.AverageRating, row.ViewCount);
        }

        private async Task<List<InteractionSignal>> LoadSignalsAsync(int userId)
            => await _dbContext.UserInteractions.AsNoTracking()
                .Where(i => i.UserId == userId)
                .Select(i => new InteractionSignal(i.Weight, i.CreatedAt, i.DestinationId, i.CategoryId, i.TagId))
                .ToListAsync();

        private async Task<HashSet<int>> LoadCompletedDestinationIdsAsync(int userId)
        {
            var ids = await _dbContext.Bookings.AsNoTracking()
                .Where(b => b.UserId == userId && b.StatusId == (int)BookingStatusCode.Completed)
                .SelectMany(b => b.TourSchedule.Tour.TourDestinations.Select(td => td.DestinationId))
                .Distinct()
                .ToListAsync();
            return ids.ToHashSet();
        }

        // Light destination cards (thumbnail only, rule 12) for the given ids, keyed by id, with the current
        // user's IsFavorite flag applied. Reuses the one shared destination projection.
        private async Task<Dictionary<int, DestinationResponse>> LoadCardsAsync(IReadOnlyCollection<int> ids, int userId)
        {
            if (ids.Count == 0)
            {
                return new Dictionary<int, DestinationResponse>();
            }

            var cards = await DestinationProjections
                .ProjectToResponse(_dbContext.Destinations.AsNoTracking().Where(d => ids.Contains(d.Id)))
                .ToListAsync();
            DestinationProjections.FinalizeThumbnails(cards);

            var favorited = await _dbContext.Favorites.AsNoTracking()
                .Where(f => f.UserId == userId && f.DestinationId != null && ids.Contains(f.DestinationId!.Value))
                .Select(f => f.DestinationId!.Value)
                .ToListAsync();
            var favoriteSet = favorited.ToHashSet();
            foreach (var card in cards)
            {
                card.IsFavorite = favoriteSet.Contains(card.Id);
            }

            return cards.ToDictionary(c => c.Id);
        }

        // Only the reference names actually referenced by the served reasons — a targeted lookup per kind.
        private async Task<FeatureNames> LoadFeatureNamesAsync(IReadOnlyCollection<FeatureKey> keys)
        {
            var categoryIds = keys.Where(k => k.Kind == FeatureKind.Category).Select(k => k.Id).Distinct().ToList();
            var tagIds = keys.Where(k => k.Kind == FeatureKind.Tag).Select(k => k.Id).Distinct().ToList();
            var regionIds = keys.Where(k => k.Kind == FeatureKind.Region).Select(k => k.Id).Distinct().ToList();

            var categories = categoryIds.Count == 0
                ? new Dictionary<int, string>()
                : await _dbContext.DestinationCategories.AsNoTracking()
                    .Where(c => categoryIds.Contains(c.Id))
                    .ToDictionaryAsync(c => c.Id, c => c.Name);
            var tags = tagIds.Count == 0
                ? new Dictionary<int, string>()
                : await _dbContext.Tags.AsNoTracking()
                    .Where(t => tagIds.Contains(t.Id))
                    .ToDictionaryAsync(t => t.Id, t => t.Name);
            var regions = regionIds.Count == 0
                ? new Dictionary<int, string>()
                : await _dbContext.Regions.AsNoTracking()
                    .Where(r => regionIds.Contains(r.Id))
                    .ToDictionaryAsync(r => r.Id, r => r.Name);

            return new FeatureNames(categories, tags, regions);
        }

        // Appends one RecommendationLog per served item (04 §4): output-only audit of what was shown, with
        // its score and explanation. Written only when the result is actually computed (not on cache hits).
        private async Task AppendLogsAsync(int userId, IReadOnlyList<RecommendationItem> items)
        {
            if (items.Count == 0)
            {
                return;
            }

            var now = DateTime.UtcNow;
            foreach (var item in items)
            {
                _dbContext.RecommendationLogs.Add(new RecommendationLog
                {
                    UserId = userId,
                    DestinationId = item.Destination.Id,
                    Score = item.Score,
                    Reason = item.Reason,
                    ServedAt = now
                });
            }
            await _dbContext.SaveChangesAsync();
        }

        // Small name lookup used to turn a top-contributor feature into a human reason; unknown ids fall back
        // to a generic phrase so a reason is never empty.
        private sealed class FeatureNames
        {
            private readonly IReadOnlyDictionary<int, string> _categories;
            private readonly IReadOnlyDictionary<int, string> _tags;
            private readonly IReadOnlyDictionary<int, string> _regions;

            public FeatureNames(
                IReadOnlyDictionary<int, string> categories,
                IReadOnlyDictionary<int, string> tags,
                IReadOnlyDictionary<int, string> regions)
            {
                _categories = categories;
                _tags = tags;
                _regions = regions;
            }

            public string Category(int id) => _categories.TryGetValue(id, out var n) ? n : "this category";
            public string Tag(int id) => _tags.TryGetValue(id, out var n) ? n : "this tag";
            public string Region(int id) => _regions.TryGetValue(id, out var n) ? n : "this region";
        }
    }
}
