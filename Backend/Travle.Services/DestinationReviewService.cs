using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Recommender;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Travle.Services
{
    /// <summary>
    /// Destination reviews domain service. Not a generic CRUD entity — the write verbs carry gating (the
    /// target must be approved; one active review per user; author-only edit/self-removal; admin-only
    /// moderation removal) and side effects (denormalized <c>AverageRating</c> recompute, a
    /// <c>ReviewHigh</c> interaction reconciled to the current 4–5★ rating, a notification on moderation removal). Reads are hand-written
    /// projections (never Mapster), and public reads never surface soft-removed rows.
    /// </summary>
    public class DestinationReviewService
        : BaseReadService<DestinationReview, DestinationReviewResponse, DestinationReviewSearch>, IDestinationReviewService
    {
        /// <summary>A review at or above this rating is a strong positive signal (04 §2).</summary>
        private const int HighRatingThreshold = 4;

        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly RecommenderOptions _recommenderOptions;
        private readonly IRecommendationCache _recommendationCache;
        private readonly IValidator<DestinationReviewInsertRequest> _insertValidator;
        private readonly IValidator<DestinationReviewUpdateRequest> _updateValidator;
        private readonly IValidator<ReviewRemoveRequest> _removeValidator;

        public DestinationReviewService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            IOptions<RecommenderOptions> recommenderOptions,
            IRecommendationCache recommendationCache,
            IValidator<DestinationReviewInsertRequest> insertValidator,
            IValidator<DestinationReviewUpdateRequest> updateValidator,
            IValidator<ReviewRemoveRequest> removeValidator)
            : base(mapper, dbContext)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _recommenderOptions = recommenderOptions.Value;
            _recommendationCache = recommendationCache;
            _insertValidator = insertValidator;
            _updateValidator = updateValidator;
            _removeValidator = removeValidator;
        }

        // --- reads -----------------------------------------------------------------------------------

        protected override IQueryable<DestinationReview> ApplyFilters(IQueryable<DestinationReview> query, DestinationReviewSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (search.DestinationId.HasValue)
            {
                query = query.Where(r => r.DestinationId == search.DestinationId.Value);
            }
            if (search.UserId.HasValue)
            {
                query = query.Where(r => r.UserId == search.UserId.Value);
            }
            if (search.MinRating.HasValue)
            {
                query = query.Where(r => r.Rating >= search.MinRating.Value);
            }

            var isAdmin = _currentUser.IsInRole(RoleNames.Admin);

            // A suspended user's reviews are withheld from public view but never deleted — they reappear on
            // unsuspend. Admins still see them (moderation). Aggregates exclude them regardless (see projections).
            if (!isAdmin)
            {
                query = query.Where(r => !r.User.IsSuspended);
            }

            // Removed rows are surfaced only to admins who explicitly ask; everyone else sees active only.
            var includeRemoved = (search.IncludeRemoved ?? false) && isAdmin;
            if (!includeRemoved)
            {
                query = query.Where(r => !r.IsRemoved);
            }

            return query;
        }

        public override async Task<PageResult<DestinationReviewResponse>> GetAllAsync(DestinationReviewSearch? search = null)
        {
            search ??= new DestinationReviewSearch();
            search.SortBy ??= "CreatedAt desc";

            IQueryable<DestinationReview> query = _dbContext.DestinationReviews.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await ProjectToResponse(query).ToListAsync();
            return new PageResult<DestinationReviewResponse> { Items = items, TotalCount = totalCount };
        }

        public override async Task<DestinationReviewResponse> GetByIdAsync(int id)
        {
            var isAdmin = _currentUser.IsInRole(RoleNames.Admin);

            IQueryable<DestinationReview> query = _dbContext.DestinationReviews.AsNoTracking().Where(r => r.Id == id);
            // A suspended author's review is invisible to non-admins (it reappears on unsuspend).
            if (!isAdmin)
            {
                query = query.Where(r => !r.User.IsSuspended);
            }

            var response = await ProjectToResponse(query).FirstOrDefaultAsync()
                ?? throw new NotFoundException("DestinationReview", id);

            // A removed review is visible only to an admin (moderation) or its author.
            if (response.IsRemoved
                && !isAdmin
                && _currentUser.GetUserId() != response.UserId)
            {
                throw new NotFoundException("DestinationReview", id);
            }

            return response;
        }

        // --- writes ----------------------------------------------------------------------------------

        public async Task<DestinationReviewResponse> CreateAsync(DestinationReviewInsertRequest request)
        {
            var userId = _authorization.RequireUserId();
            await _insertValidator.ValidateAndThrowAsync(request);

            var status = await _dbContext.Destinations
                .Where(d => d.Id == request.DestinationId)
                .Select(d => (DestinationStatus?)d.Status)
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Destination", request.DestinationId);

            if (status != DestinationStatus.Approved)
            {
                throw new BusinessRuleException("Only an approved destination can be reviewed.");
            }

            var alreadyReviewed = await _dbContext.DestinationReviews
                .AnyAsync(r => r.DestinationId == request.DestinationId && r.UserId == userId && !r.IsRemoved);
            if (alreadyReviewed)
            {
                throw new ConflictException("You have already reviewed this destination. Edit your existing review instead.");
            }

            var review = new DestinationReview
            {
                DestinationId = request.DestinationId,
                UserId = userId,
                Rating = request.Rating,
                Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim()
            };

            // Insert + average recompute + (maybe) the ReviewHigh interaction are several DB operations →
            // one explicit transaction (rule 7).
            await using var transaction = await _dbContext.Database.BeginTransactionAsync();

            _dbContext.DestinationReviews.Add(review);
            await _dbContext.SaveChangesAsync();

            await RecomputeAverageRatingAsync(request.DestinationId);
            await ReconcileReviewHighAsync(userId, request.DestinationId, request.Rating >= HighRatingThreshold);

            await transaction.CommitAsync();

            // A create may have added a ReviewHigh signal → drop the author's cached recommendations (04 §4).
            _recommendationCache.InvalidateUser(userId);
            return await RequireResponseAsync(review.Id);
        }

        public async Task<DestinationReviewResponse> UpdateAsync(int id, DestinationReviewUpdateRequest request)
        {
            await _updateValidator.ValidateAndThrowAsync(request);

            var review = await _dbContext.DestinationReviews.FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("DestinationReview", id);

            EnsureAuthor(review.UserId);
            if (review.IsRemoved)
            {
                throw new BusinessRuleException("This review has been removed and can no longer be edited.");
            }

            review.Rating = request.Rating;
            review.Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();

            await using var transaction = await _dbContext.Database.BeginTransactionAsync();

            await _dbContext.SaveChangesAsync();
            await RecomputeAverageRatingAsync(review.DestinationId);
            // Reconcile the strong signal to the edited rating: a move up into the 4–5★ band adds the
            // ReviewHigh row, a move below it drops the row (04 §2 reconcile-on-edit).
            await ReconcileReviewHighAsync(review.UserId, review.DestinationId, review.Rating >= HighRatingThreshold);

            await transaction.CommitAsync();

            // The reconcile may have added/removed the ReviewHigh signal → invalidate the author (04 §4).
            _recommendationCache.InvalidateUser(review.UserId);
            return await RequireResponseAsync(id);
        }

        public async Task RemoveOwnAsync(int id)
        {
            var review = await _dbContext.DestinationReviews.FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("DestinationReview", id);

            var userId = EnsureAuthor(review.UserId);
            if (review.IsRemoved)
            {
                throw new BusinessRuleException("This review has already been removed.");
            }

            review.IsRemoved = true;
            review.RemovedByUserId = userId;
            review.RemovalReason = null; // self-removal carries no moderation reason

            await using var transaction = await _dbContext.Database.BeginTransactionAsync();

            await _dbContext.SaveChangesAsync();
            await RecomputeAverageRatingAsync(review.DestinationId);
            // The review is gone, so its ReviewHigh signal must go too (04 §2 reconcile-on-removal).
            await ReconcileReviewHighAsync(review.UserId, review.DestinationId, shouldExist: false);

            await transaction.CommitAsync();

            // The dropped ReviewHigh signal changed the profile → invalidate the author (04 §4).
            _recommendationCache.InvalidateUser(review.UserId);
        }

        public async Task<DestinationReviewResponse> RemoveAsync(int id, ReviewRemoveRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();
            await _removeValidator.ValidateAndThrowAsync(request);

            var review = await _dbContext.DestinationReviews
                .Include(r => r.Destination)
                .FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("DestinationReview", id);

            if (review.IsRemoved)
            {
                throw new BusinessRuleException("This review has already been removed.");
            }

            var reason = request.Reason.Trim();
            review.IsRemoved = true;
            review.RemovedByUserId = adminId;
            review.RemovalReason = reason;

            _dbContext.Notifications.Add(new Notification
            {
                UserId = review.UserId,
                Type = NotificationType.ReviewRemoved,
                Title = "Review removed",
                Text = $"Your review of '{review.Destination.Name}' was removed by a moderator. Reason: {reason}",
                RelatedEntityId = review.DestinationId,
                IsRead = false
            });

            await using var transaction = await _dbContext.Database.BeginTransactionAsync();

            await _dbContext.SaveChangesAsync();
            await RecomputeAverageRatingAsync(review.DestinationId);
            // Moderation removal retires the review, so its ReviewHigh signal is dropped as well (04 §2).
            await ReconcileReviewHighAsync(review.UserId, review.DestinationId, shouldExist: false);

            await transaction.CommitAsync();

            // The dropped ReviewHigh signal changed the profile → invalidate the author (04 §4).
            _recommendationCache.InvalidateUser(review.UserId);
            return await RequireResponseAsync(id);
        }

        // --- helpers ---------------------------------------------------------------------------------

        private static IQueryable<DestinationReviewResponse> ProjectToResponse(IQueryable<DestinationReview> query)
            => query.Select(r => new DestinationReviewResponse
            {
                Id = r.Id,
                DestinationId = r.DestinationId,
                DestinationName = r.Destination.Name,
                UserId = r.UserId,
                Username = r.User.Username,
                AuthorName = r.User.FirstName + " " + r.User.LastName,
                Rating = r.Rating,
                Comment = r.Comment,
                IsRemoved = r.IsRemoved,
                RemovedByUserId = r.RemovedByUserId,
                RemovedByUsername = r.RemovedByUser != null ? r.RemovedByUser.Username : null,
                RemovalReason = r.RemovalReason,
                CreatedAt = r.CreatedAt,
                ModifiedAt = r.ModifiedAt
            });

        private async Task<DestinationReviewResponse> RequireResponseAsync(int id)
            => await ProjectToResponse(_dbContext.DestinationReviews.AsNoTracking().Where(r => r.Id == id))
                   .FirstOrDefaultAsync()
               ?? throw new NotFoundException("DestinationReview", id);

        // Recomputes the destination's denormalized average over its non-removed reviews (0 when none),
        // straight in SQL (no entity load). Runs inside the caller's transaction.
        private async Task RecomputeAverageRatingAsync(int destinationId)
        {
            var average = await _dbContext.DestinationReviews
                .Where(r => r.DestinationId == destinationId && !r.IsRemoved)
                .Select(r => (double?)r.Rating)
                .AverageAsync() ?? 0d;

            await _dbContext.Destinations
                .Where(d => d.Id == destinationId)
                .ExecuteUpdateAsync(setters => setters.SetProperty(d => d.AverageRating, average));
        }

        // Keeps the ReviewHigh interaction in lockstep with the user's *current* review of a destination
        // (04 §2 reconcile-on-edit). A 4–5★ review contributes exactly one ReviewHigh row; if the user later
        // edits the rating below the threshold, or the review is removed (self or moderation), that row is
        // dropped — its defining precondition ("rated 4–5") no longer holds, so unlike the other signals it
        // is NOT append-only. A user has at most one active review per destination, so a single
        // (user, destination) ReviewHigh row is the whole state. Destination-targeted only (tour reviews do
        // not feed the recommender). Runs inside the caller's transaction.
        private async Task ReconcileReviewHighAsync(int userId, int destinationId, bool shouldExist)
        {
            var existing = await _dbContext.UserInteractions.FirstOrDefaultAsync(i =>
                i.UserId == userId
                && i.DestinationId == destinationId
                && i.InteractionType == InteractionType.ReviewHigh);

            if (shouldExist && existing is null)
            {
                _dbContext.UserInteractions.Add(new UserInteraction
                {
                    UserId = userId,
                    DestinationId = destinationId,
                    InteractionType = InteractionType.ReviewHigh,
                    Weight = _recommenderOptions.Weights.ReviewHigh
                });
            }
            else if (!shouldExist && existing is not null)
            {
                _dbContext.UserInteractions.Remove(existing);
            }

            await _dbContext.SaveChangesAsync();
        }

        private int EnsureAuthor(int authorUserId)
        {
            var userId = _authorization.RequireUserId();
            if (userId != authorUserId)
            {
                throw new ForbiddenException("You can only modify your own review.");
            }
            return userId;
        }
    }
}
