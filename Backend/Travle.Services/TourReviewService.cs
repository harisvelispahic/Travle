using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    /// <summary>
    /// Tour reviews domain service. The write verbs carry gating (own Completed booking; one review per
    /// booking; author-only edit; admin-only moderation removal) but no denormalized recompute (tour
    /// ratings are aggregated on read) and no recommender interaction (tour signals are out of the
    /// destination-based feature space by decision). Reads are hand-written projections; public reads never
    /// surface soft-removed rows.
    /// </summary>
    public class TourReviewService
        : BaseReadService<TourReview, TourReviewResponse, TourReviewSearch>, ITourReviewService
    {
        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly IValidator<TourReviewInsertRequest> _insertValidator;
        private readonly IValidator<TourReviewUpdateRequest> _updateValidator;
        private readonly IValidator<ReviewRemoveRequest> _removeValidator;

        public TourReviewService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            IValidator<TourReviewInsertRequest> insertValidator,
            IValidator<TourReviewUpdateRequest> updateValidator,
            IValidator<ReviewRemoveRequest> removeValidator)
            : base(mapper, dbContext)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _insertValidator = insertValidator;
            _updateValidator = updateValidator;
            _removeValidator = removeValidator;
        }

        // --- reads -----------------------------------------------------------------------------------

        protected override IQueryable<TourReview> ApplyFilters(IQueryable<TourReview> query, TourReviewSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (search.TourId.HasValue)
            {
                query = query.Where(r => r.TourId == search.TourId.Value);
            }
            if (search.OrganizerId.HasValue)
            {
                query = query.Where(r => r.Tour.OrganizerId == search.OrganizerId.Value);
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

            var includeRemoved = (search.IncludeRemoved ?? false) && isAdmin;
            if (!includeRemoved)
            {
                query = query.Where(r => !r.IsRemoved);
            }

            return query;
        }

        public override async Task<PageResult<TourReviewResponse>> GetAllAsync(TourReviewSearch? search = null)
        {
            search ??= new TourReviewSearch();
            search.SortBy ??= "CreatedAt desc";

            IQueryable<TourReview> query = _dbContext.TourReviews.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await ProjectToResponse(query).ToListAsync();
            return new PageResult<TourReviewResponse> { Items = items, TotalCount = totalCount };
        }

        public override async Task<TourReviewResponse> GetByIdAsync(int id)
        {
            var isAdmin = _currentUser.IsInRole(RoleNames.Admin);

            IQueryable<TourReview> query = _dbContext.TourReviews.AsNoTracking().Where(r => r.Id == id);
            // A suspended author's review is invisible to non-admins (it reappears on unsuspend).
            if (!isAdmin)
            {
                query = query.Where(r => !r.User.IsSuspended);
            }

            var response = await ProjectToResponse(query).FirstOrDefaultAsync()
                ?? throw new NotFoundException("TourReview", id);

            if (response.IsRemoved
                && !isAdmin
                && _currentUser.GetUserId() != response.UserId)
            {
                throw new NotFoundException("TourReview", id);
            }

            return response;
        }

        public async Task<PageResult<TourReviewResponse>> GetForMyToursAsync(TourReviewSearch? search)
        {
            var userId = _authorization.RequireUserId();
            _authorization.EnsureInRole(RoleNames.Organizer);
            search ??= new TourReviewSearch();
            // Force scoping to the organizer's own tours; a caller can never widen it.
            search.OrganizerId = userId;
            return await GetAllAsync(search);
        }

        // --- writes ----------------------------------------------------------------------------------

        public async Task<TourReviewResponse> CreateAsync(TourReviewInsertRequest request)
        {
            var userId = _authorization.RequireUserId();
            await _insertValidator.ValidateAndThrowAsync(request);

            var booking = await _dbContext.Bookings
                .Where(b => b.Id == request.BookingId)
                .Select(b => new { b.UserId, b.StatusId, TourId = b.TourSchedule.TourId })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Booking", request.BookingId);

            if (booking.UserId != userId)
            {
                throw new ForbiddenException("You can only review your own bookings.");
            }
            if (booking.StatusId != (int)BookingStatusCode.Completed)
            {
                throw new BusinessRuleException("You can review a tour only after your booking is completed.");
            }

            // One review per booking (unique index on BookingId). If a row already exists we either block
            // (active, or an admin-removed one — moderation is final) or reactivate the author's own prior
            // self-removal, reusing the row so the unique index is honoured (03 §3).
            var existing = await _dbContext.TourReviews.FirstOrDefaultAsync(r => r.BookingId == request.BookingId);
            if (existing is not null)
            {
                if (!existing.IsRemoved)
                {
                    throw new ConflictException("You have already reviewed this booking.");
                }
                if (existing.RemovedByUserId != userId)
                {
                    throw new ConflictException("This review was removed by a moderator and cannot be re-created.");
                }

                existing.Rating = request.Rating;
                existing.Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
                existing.IsRemoved = false;
                existing.RemovedByUserId = null;
                existing.RemovalReason = null;
                await _dbContext.SaveChangesAsync();

                return await RequireResponseAsync(existing.Id);
            }

            var review = new TourReview
            {
                TourId = booking.TourId,
                BookingId = request.BookingId,
                UserId = userId,
                Rating = request.Rating,
                Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim()
            };

            _dbContext.TourReviews.Add(review);
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(review.Id);
        }

        public async Task<TourReviewResponse> UpdateAsync(int id, TourReviewUpdateRequest request)
        {
            await _updateValidator.ValidateAndThrowAsync(request);

            var review = await _dbContext.TourReviews.FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("TourReview", id);

            var userId = _authorization.RequireUserId();
            if (review.UserId != userId)
            {
                throw new ForbiddenException("You can only modify your own review.");
            }
            if (review.IsRemoved)
            {
                throw new BusinessRuleException("This review has been removed and can no longer be edited.");
            }

            review.Rating = request.Rating;
            review.Comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        public async Task RemoveOwnAsync(int id)
        {
            var review = await _dbContext.TourReviews.FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("TourReview", id);

            var userId = _authorization.RequireUserId();
            if (review.UserId != userId)
            {
                throw new ForbiddenException("You can only modify your own review.");
            }
            if (review.IsRemoved)
            {
                throw new BusinessRuleException("This review has already been removed.");
            }

            // Self-removal: soft-remove, tagging the author as the remover so a later re-review can tell it
            // apart from an admin moderation removal (which is final). Tour ratings are computed on read, so
            // there is nothing to recompute.
            review.IsRemoved = true;
            review.RemovedByUserId = userId;
            review.RemovalReason = null;
            await _dbContext.SaveChangesAsync();
        }

        public async Task<TourReviewResponse> RemoveAsync(int id, ReviewRemoveRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();
            await _removeValidator.ValidateAndThrowAsync(request);

            var review = await _dbContext.TourReviews
                .Include(r => r.Tour)
                .FirstOrDefaultAsync(r => r.Id == id)
                ?? throw new NotFoundException("TourReview", id);

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
                Text = $"Your review of the tour '{review.Tour.Name}' was removed by a moderator. Reason: {reason}",
                RelatedEntityId = review.TourId,
                IsRead = false
            });

            // Review update + notification insert commit together in a single SaveChanges.
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        // --- helpers ---------------------------------------------------------------------------------

        private static IQueryable<TourReviewResponse> ProjectToResponse(IQueryable<TourReview> query)
            => query.Select(r => new TourReviewResponse
            {
                Id = r.Id,
                TourId = r.TourId,
                TourName = r.Tour.Name,
                BookingId = r.BookingId,
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

        private async Task<TourReviewResponse> RequireResponseAsync(int id)
            => await ProjectToResponse(_dbContext.TourReviews.AsNoTracking().Where(r => r.Id == id))
                   .FirstOrDefaultAsync()
               ?? throw new NotFoundException("TourReview", id);
    }
}
