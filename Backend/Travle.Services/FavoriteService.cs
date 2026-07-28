using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Projections;
using Travle.Services.Recommender;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Travle.Services
{
    /// <summary>
    /// Favorites domain service. A toggle plus two "my favorites" lists — not a generic CRUD entity. The
    /// toggle enforces the target exists and is browsable (approved destination / active tour), records the
    /// destination <c>Favorite</c> interaction on favoriting, and hard-deletes the row on un-favoriting.
    /// The lists reuse the shared destination/tour card projections (thumbnails only, rule 12) and order by
    /// favorite recency.
    /// </summary>
    public class FavoriteService : IFavoriteService
    {
        private const int MaxPageSize = 100;
        private const int DefaultPageSize = 10;

        private readonly TravleDbContext _dbContext;
        private readonly IAppAuthorizationService _authorization;
        private readonly RecommenderOptions _recommenderOptions;
        private readonly IValidator<FavoriteToggleRequest> _toggleValidator;

        public FavoriteService(
            TravleDbContext dbContext,
            IAppAuthorizationService authorization,
            IOptions<RecommenderOptions> recommenderOptions,
            IValidator<FavoriteToggleRequest> toggleValidator)
        {
            _dbContext = dbContext;
            _authorization = authorization;
            _recommenderOptions = recommenderOptions.Value;
            _toggleValidator = toggleValidator;
        }

        public async Task<FavoriteToggleResponse> ToggleAsync(FavoriteToggleRequest request)
        {
            var userId = _authorization.RequireUserId();
            await _toggleValidator.ValidateAndThrowAsync(request);

            return request.DestinationId is int destinationId
                ? await ToggleDestinationAsync(userId, destinationId)
                : await ToggleTourAsync(userId, request.TourId!.Value);
        }

        public async Task<PageResult<DestinationResponse>> GetMyDestinationsAsync(DestinationSearch? search)
        {
            var userId = _authorization.RequireUserId();
            search ??= new DestinationSearch();

            IQueryable<Destination> query = _dbContext.Destinations.AsNoTracking()
                .Where(d => _dbContext.Favorites.Any(f => f.UserId == userId && f.DestinationId == d.Id));

            query = ApplyDestinationText(query, search.Text);
            if (search.CategoryId.HasValue)
            {
                query = query.Where(d => d.CategoryId == search.CategoryId.Value);
            }

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            // Newest favorited first (the correlated favorite row's timestamp).
            query = query.OrderByDescending(d => _dbContext.Favorites
                .Where(f => f.UserId == userId && f.DestinationId == d.Id)
                .Select(f => f.CreatedAt)
                .FirstOrDefault());
            query = Paginate(query, search);

            var items = await DestinationProjections.ProjectToResponse(query).ToListAsync();
            DestinationProjections.FinalizeThumbnails(items);
            foreach (var item in items)
            {
                item.IsFavorite = true; // by definition — this is the favorites list
            }

            return new PageResult<DestinationResponse> { Items = items, TotalCount = totalCount };
        }

        public async Task<PageResult<TourResponse>> GetMyToursAsync(TourSearch? search)
        {
            var userId = _authorization.RequireUserId();
            search ??= new TourSearch();
            var now = DateTime.UtcNow;

            IQueryable<Tour> query = _dbContext.Tours.AsNoTracking()
                .Where(t => _dbContext.Favorites.Any(f => f.UserId == userId && f.TourId == t.Id))
                // Hide a favorited tour whose organizer is currently suspended (reappears on unsuspend).
                .Where(t => !t.Organizer.IsSuspended);

            query = ApplyTourText(query, search.Text);
            if (search.TourTypeId.HasValue)
            {
                query = query.Where(t => t.TourTypeId == search.TourTypeId.Value);
            }

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = query.OrderByDescending(t => _dbContext.Favorites
                .Where(f => f.UserId == userId && f.TourId == t.Id)
                .Select(f => f.CreatedAt)
                .FirstOrDefault());
            query = Paginate(query, search);

            var items = await TourProjections.ProjectToListResponse(query, now).ToListAsync();
            TourProjections.FinalizeThumbnails(items);
            foreach (var item in items)
            {
                item.IsFavorite = true;
            }

            return new PageResult<TourResponse> { Items = items, TotalCount = totalCount };
        }

        // --- helpers ---------------------------------------------------------------------------------

        private async Task<FavoriteToggleResponse> ToggleDestinationAsync(int userId, int destinationId)
        {
            var status = await _dbContext.Destinations
                .Where(d => d.Id == destinationId)
                .Select(d => (DestinationStatus?)d.Status)
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Destination", destinationId);

            if (status != DestinationStatus.Approved)
            {
                throw new BusinessRuleException("Only an approved destination can be added to favorites.");
            }

            var existing = await _dbContext.Favorites
                .FirstOrDefaultAsync(f => f.UserId == userId && f.DestinationId == destinationId);

            if (existing is not null)
            {
                _dbContext.Favorites.Remove(existing);
                await _dbContext.SaveChangesAsync();
                return Result("Destination", destinationId, isFavorite: false);
            }

            // Favorite row + the recommender Favorite interaction insert together in one SaveChanges.
            _dbContext.Favorites.Add(new Favorite { UserId = userId, DestinationId = destinationId });
            _dbContext.UserInteractions.Add(new UserInteraction
            {
                UserId = userId,
                DestinationId = destinationId,
                InteractionType = InteractionType.Favorite,
                Weight = _recommenderOptions.Weights.Favorite
            });
            await _dbContext.SaveChangesAsync();
            return Result("Destination", destinationId, isFavorite: true);
        }

        private async Task<FavoriteToggleResponse> ToggleTourAsync(int userId, int tourId)
        {
            var isActive = await _dbContext.Tours
                .Where(t => t.Id == tourId)
                .Select(t => (bool?)t.IsActive)
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Tour", tourId);

            if (isActive == false)
            {
                throw new BusinessRuleException("Only an active tour can be added to favorites.");
            }

            var existing = await _dbContext.Favorites
                .FirstOrDefaultAsync(f => f.UserId == userId && f.TourId == tourId);

            if (existing is not null)
            {
                _dbContext.Favorites.Remove(existing);
                await _dbContext.SaveChangesAsync();
                return Result("Tour", tourId, isFavorite: false);
            }

            // Tour favorites record no recommender interaction (destination-based feature space, by decision).
            _dbContext.Favorites.Add(new Favorite { UserId = userId, TourId = tourId });
            await _dbContext.SaveChangesAsync();
            return Result("Tour", tourId, isFavorite: true);
        }

        private static FavoriteToggleResponse Result(string targetType, int targetId, bool isFavorite)
            => new() { TargetType = targetType, TargetId = targetId, IsFavorite = isFavorite };

        // Accent-aware name/description search, mirroring the destinations service (SearchCollation): a
        // plain term is accent-insensitive, an accented term stays accent-sensitive (compile-time literal
        // collation per branch).
        private static IQueryable<Destination> ApplyDestinationText(IQueryable<Destination> query, string? text)
            => query.WhereContains(text, d => d.Name, d => d.Description);

        private static IQueryable<Tour> ApplyTourText(IQueryable<Tour> query, string? text)
            => query.WhereContains(text, t => t.Name, t => t.Description);

        // Local paging (this service does not extend BaseReadService); same MaxPageSize clamp so a
        // favorites list can never return an unbounded set.
        private static IQueryable<T> Paginate<T>(IQueryable<T> query, BaseSearchObject search)
        {
            var page = search.Page is int p && p > 0 ? p : 1;

            var pageSize = search.PageSize ?? DefaultPageSize;
            if (pageSize < 1)
            {
                pageSize = DefaultPageSize;
            }
            if (pageSize > MaxPageSize)
            {
                pageSize = MaxPageSize;
            }

            return query.Skip((page - 1) * pageSize).Take(pageSize);
        }
    }
}
