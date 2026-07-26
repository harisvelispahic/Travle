using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Imaging;
using Travle.Services.Recommender;
using Travle.Services.Security;
using FluentValidation;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Travle.Services
{
    /// <summary>
    /// Destinations domain service. A genuine CRUD entity (submit / edit / delete are real endpoints),
    /// so it extends <see cref="BaseCRUDService{TEntity,TResponse,TSearch,TInsertRequest,TUpdateRequest}"/>
    /// for the standard contract, but the three verbs are overridden because their default bodies can't
    /// express JWT-owner assignment, async thumbnailing, child collections, or the reset-to-Pending rule.
    /// Every read is a hand-written <see cref="Select"/> projection so the heavy full-image bytes are
    /// never loaded into a list/detail response (§8.2) — only the primary thumbnail travels inline.
    /// </summary>
    public class DestinationService
        : BaseCRUDService<Destination, DestinationResponse, DestinationSearch, DestinationInsertRequest, DestinationUpdateRequest>,
          IDestinationService
    {
        private const string ThumbnailContentType = "image/jpeg";

        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly IThumbnailGenerator _thumbnailGenerator;
        private readonly RecommenderOptions _recommenderOptions;
        private readonly IValidator<DestinationRejectRequest> _rejectValidator;

        public DestinationService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            IThumbnailGenerator thumbnailGenerator,
            IOptions<RecommenderOptions> recommenderOptions,
            IValidator<DestinationInsertRequest> insertValidator,
            IValidator<DestinationUpdateRequest> updateValidator,
            IValidator<DestinationRejectRequest> rejectValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _thumbnailGenerator = thumbnailGenerator;
            _recommenderOptions = recommenderOptions.Value;
            _rejectValidator = rejectValidator;
        }

        protected override IQueryable<Destination> ApplyFilters(IQueryable<Destination> query, DestinationSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            if (!string.IsNullOrWhiteSpace(search.Text))
            {
                var text = search.Text;
                // Asymmetric accent handling driven by the term (see SearchCollation): plain terms match
                // accent-insensitively; an accented term stays accent-sensitive. Literal collation per branch.
                query = SearchCollation.HasDiacritics(text)
                    ? query.Where(d =>
                        EF.Functions.Collate(d.Name, SearchCollation.CaseInsensitiveAccentSensitive).Contains(text)
                        || EF.Functions.Collate(d.Description, SearchCollation.CaseInsensitiveAccentSensitive).Contains(text))
                    : query.Where(d =>
                        EF.Functions.Collate(d.Name, SearchCollation.CaseInsensitiveAccentInsensitive).Contains(text)
                        || EF.Functions.Collate(d.Description, SearchCollation.CaseInsensitiveAccentInsensitive).Contains(text));
            }

            if (search.CategoryId.HasValue)
            {
                query = query.Where(d => d.CategoryId == search.CategoryId.Value);
            }

            if (search.RegionId.HasValue)
            {
                query = query.Where(d => d.City.RegionId == search.RegionId.Value);
            }

            if (search.CityId.HasValue)
            {
                query = query.Where(d => d.CityId == search.CityId.Value);
            }

            if (search.MinRating.HasValue)
            {
                query = query.Where(d => d.AverageRating >= search.MinRating.Value);
            }

            if (search.Status.HasValue)
            {
                var status = (DestinationStatus)search.Status.Value;
                query = query.Where(d => d.Status == status);
            }

            if (search.SubmittedByUserId.HasValue)
            {
                query = query.Where(d => d.SubmittedByUserId == search.SubmittedByUserId.Value);
            }

            if (search.IsFeatured.HasValue)
            {
                query = query.Where(d => d.IsFeatured == search.IsFeatured.Value);
            }

            return query;
        }

        // Every read goes through a projection (never Mapster / Include) so full ImageData is never loaded.
        public override async Task<PageResult<DestinationResponse>> GetAllAsync(DestinationSearch? search = null)
        {
            IQueryable<Destination> query = _dbContext.Destinations.AsNoTracking();
            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);

            var items = await ProjectToResponse(query).ToListAsync();
            FinalizeThumbnails(items);

            return new PageResult<DestinationResponse> { Items = items, TotalCount = totalCount };
        }

        public override Task<DestinationResponse> GetByIdAsync(int id) => RequireResponseAsync(id);

        public async Task<PageResult<DestinationResponse>> SearchAsync(DestinationSearch? search)
        {
            search ??= new DestinationSearch();
            // The public catalog is approved-only; a caller can never widen it to pending/rejected rows
            // or scope it to another submitter.
            search.Status = (int)DestinationStatus.Approved;
            search.SubmittedByUserId = null;
            search.SortBy ??= "AverageRating desc";

            if (!string.IsNullOrWhiteSpace(search.Text))
            {
                await RecordSearchInteractionAsync(search.Text.Trim(), search.CategoryId);
            }

            return await GetAllAsync(search);
        }

        public async Task<PageResult<DestinationResponse>> GetMineAsync(DestinationSearch? search)
        {
            var userId = _authorization.RequireUserId();
            _authorization.EnsureInAnyRole(RoleNames.Curator, RoleNames.Organizer);
            search ??= new DestinationSearch();
            // Force ownership scoping: a caller can never widen this to another curator's destinations.
            search.SubmittedByUserId = userId;
            search.SortBy ??= "CreatedAt desc";
            return await GetAllAsync(search);
        }

        public async Task<PageResult<DestinationResponse>> GetModerationQueueAsync(DestinationSearch? search)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            search ??= new DestinationSearch();
            // Default the queue to what needs a decision, but allow filtering to approved/rejected too.
            search.Status ??= (int)DestinationStatus.Pending;
            search.SortBy ??= "CreatedAt desc";
            return await GetAllAsync(search);
        }

        public async Task<DestinationResponse> GetDetailAsync(int id)
        {
            var meta = await _dbContext.Destinations
                .AsNoTracking()
                .Where(d => d.Id == id)
                .Select(d => new { d.Status, d.SubmittedByUserId })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Destination", id);

            // Opening an approved destination someone else submitted logs a View and bumps ViewCount —
            // recommender fuel + the popularity term. Self-views and non-approved rows never count.
            var viewerId = _currentUser.GetUserId();
            if (meta.Status == DestinationStatus.Approved && viewerId.HasValue && viewerId.Value != meta.SubmittedByUserId)
            {
                // ExecuteUpdateAsync (bump) + the interaction insert are two DB operations → one explicit
                // transaction (rule 7).
                await using var transaction = await _dbContext.Database.BeginTransactionAsync();

                await _dbContext.Destinations
                    .Where(d => d.Id == id)
                    .ExecuteUpdateAsync(setters => setters.SetProperty(d => d.ViewCount, d => d.ViewCount + 1));

                _dbContext.UserInteractions.Add(new UserInteraction
                {
                    UserId = viewerId.Value,
                    DestinationId = id,
                    InteractionType = InteractionType.View,
                    Weight = _recommenderOptions.Weights.View
                });
                await _dbContext.SaveChangesAsync();
                await transaction.CommitAsync();
            }

            return await RequireResponseAsync(id);
        }

        public override async Task<DestinationResponse> InsertAsync(DestinationInsertRequest request)
        {
            // Only curators/organizers submit destinations; the submitter is the JWT user.
            _authorization.EnsureInAnyRole(RoleNames.Curator, RoleNames.Organizer);
            var userId = _authorization.RequireUserId();

            await _insertValidator.ValidateAndThrowAsync(request);
            await EnsureReferencesExistAsync(request.CategoryId, request.CityId, request.TagIds);

            var destination = new Destination
            {
                Name = request.Name.Trim(),
                Description = request.Description.Trim(),
                CategoryId = request.CategoryId,
                CityId = request.CityId,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                EntranceFee = request.EntranceFee,
                SubmittedByUserId = userId,
                Status = DestinationStatus.Pending
            };

            foreach (var tagId in request.TagIds.Distinct())
            {
                destination.DestinationTags.Add(new DestinationTag { TagId = tagId });
            }

            var orderedImages = request.Images.OrderBy(i => i.SortOrder).ToList();
            for (var index = 0; index < orderedImages.Count; index++)
            {
                var image = orderedImages[index];
                destination.Images.Add(await BuildImageAsync(image.Data, image.ContentType, index));
            }

            _dbContext.Destinations.Add(destination);
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(destination.Id);
        }

        public override async Task<DestinationResponse> UpdateAsync(int id, DestinationUpdateRequest request)
        {
            await _updateValidator.ValidateAndThrowAsync(request);

            var destination = await _dbContext.Destinations
                .Include(d => d.DestinationTags)
                .Include(d => d.Images)
                .FirstOrDefaultAsync(d => d.Id == id)
                ?? throw new NotFoundException("Destination", id);

            // The submitter (or an admin) may edit; nobody else.
            _authorization.EnsureSelfOrAdmin(destination.SubmittedByUserId, "destination");
            await EnsureReferencesExistAsync(request.CategoryId, request.CityId, request.TagIds);

            destination.Name = request.Name.Trim();
            destination.Description = request.Description.Trim();
            destination.CategoryId = request.CategoryId;
            destination.CityId = request.CityId;
            destination.Latitude = request.Latitude;
            destination.Longitude = request.Longitude;
            destination.EntranceFee = request.EntranceFee;

            // Any edit sends the destination back for moderation (course rule); clear the prior decision.
            destination.Status = DestinationStatus.Pending;
            destination.ModeratedByUserId = null;
            destination.ModeratedAt = null;
            destination.RejectionReason = null;

            ReconcileTags(destination, request.TagIds);
            await ReconcileImagesAsync(destination, request.Images);

            // All reconciliation is tracked in one SaveChanges → a single implicit transaction.
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        public override async Task DeleteAsync(int id)
        {
            var destination = await _dbContext.Destinations.FirstOrDefaultAsync(d => d.Id == id)
                ?? throw new NotFoundException("Destination", id);

            _authorization.EnsureSelfOrAdmin(destination.SubmittedByUserId, "destination");

            if (destination.Status != DestinationStatus.Pending)
            {
                throw new ConflictException(
                    "Only a pending destination can be deleted. Approved or rejected destinations are kept for their moderation history.");
            }

            var tourRefs = await _dbContext.TourDestinations.CountAsync(td => td.DestinationId == id);
            if (tourRefs > 0)
            {
                throw new ConflictException($"Cannot delete this destination: it is used by {tourRefs} tour(s).");
            }

            var reviewRefs = await _dbContext.DestinationReviews.CountAsync(r => r.DestinationId == id);
            if (reviewRefs > 0)
            {
                throw new ConflictException($"Cannot delete this destination: it has {reviewRefs} review(s).");
            }

            var favoriteRefs = await _dbContext.Favorites.CountAsync(f => f.DestinationId == id);
            if (favoriteRefs > 0)
            {
                throw new ConflictException($"Cannot delete this destination: it is in {favoriteRefs} user favorite(s).");
            }

            _dbContext.Destinations.Remove(destination); // images cascade away
            await _dbContext.SaveChangesAsync();
        }

        public async Task<DestinationResponse> ApproveAsync(int id)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();

            var destination = await _dbContext.Destinations.FirstOrDefaultAsync(d => d.Id == id)
                ?? throw new NotFoundException("Destination", id);

            EnsurePending(destination);

            destination.Status = DestinationStatus.Approved;
            destination.ModeratedByUserId = adminId;
            destination.ModeratedAt = DateTime.UtcNow;
            destination.RejectionReason = null;

            AddModerationNotification(
                destination.SubmittedByUserId,
                NotificationType.DestinationApproved,
                "Destination approved",
                $"Your destination '{destination.Name}' has been approved and is now published.",
                destination.Id);

            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        public async Task<DestinationResponse> RejectAsync(int id, DestinationRejectRequest request)
        {
            _authorization.EnsureInRole(RoleNames.Admin);
            var adminId = _authorization.RequireUserId();
            await _rejectValidator.ValidateAndThrowAsync(request);

            var destination = await _dbContext.Destinations.FirstOrDefaultAsync(d => d.Id == id)
                ?? throw new NotFoundException("Destination", id);

            EnsurePending(destination);

            destination.Status = DestinationStatus.Rejected;
            destination.ModeratedByUserId = adminId;
            destination.ModeratedAt = DateTime.UtcNow;
            destination.RejectionReason = request.Reason.Trim();
            destination.IsFeatured = false;

            AddModerationNotification(
                destination.SubmittedByUserId,
                NotificationType.DestinationRejected,
                "Destination rejected",
                $"Your destination '{destination.Name}' was not approved. Reason: {request.Reason.Trim()}",
                destination.Id);

            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        public async Task<DestinationResponse> SetFeaturedAsync(int id, bool isFeatured)
        {
            _authorization.EnsureInRole(RoleNames.Admin);

            var destination = await _dbContext.Destinations.FirstOrDefaultAsync(d => d.Id == id)
                ?? throw new NotFoundException("Destination", id);

            if (isFeatured && destination.Status != DestinationStatus.Approved)
            {
                throw new BusinessRuleException("Only an approved destination can be featured.");
            }

            destination.IsFeatured = isFeatured;
            await _dbContext.SaveChangesAsync();

            return await RequireResponseAsync(id);
        }

        public async Task<(byte[] Content, string ContentType)> GetImageAsync(int destinationId, int imageId)
        {
            var image = await _dbContext.DestinationImages
                .AsNoTracking()
                .Where(i => i.Id == imageId && i.DestinationId == destinationId)
                .Select(i => new
                {
                    i.ImageData,
                    i.ContentType,
                    i.Destination.Status,
                    i.Destination.SubmittedByUserId
                })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Image", imageId);

            // Approved images are public to any authenticated user; unpublished ones stay owner/admin only.
            if (image.Status != DestinationStatus.Approved)
            {
                _authorization.EnsureSelfOrAdmin(image.SubmittedByUserId, "destination");
            }

            return (image.ImageData, image.ContentType);
        }

        // --- helpers -----------------------------------------------------------------------------

        // Projects to the response shape entirely in SQL, pulling only the primary image's thumbnail
        // bytes (never the full ImageData of any image) plus lightweight image/tag metadata.
        private static IQueryable<DestinationResponse> ProjectToResponse(IQueryable<Destination> query)
            => query.Select(d => new DestinationResponse
            {
                Id = d.Id,
                Name = d.Name,
                Description = d.Description,
                CategoryId = d.CategoryId,
                CategoryName = d.Category.Name,
                CityId = d.CityId,
                CityName = d.City.Name,
                RegionName = d.City.Region.Name,
                CountryName = d.City.Region.Country.Name,
                Latitude = d.Latitude,
                Longitude = d.Longitude,
                EntranceFee = d.EntranceFee,
                Status = d.Status.ToString(),
                IsFeatured = d.IsFeatured,
                AverageRating = d.AverageRating,
                ViewCount = d.ViewCount,
                SubmittedByUserId = d.SubmittedByUserId,
                SubmittedByUsername = d.SubmittedByUser.Username,
                ModeratedByUserId = d.ModeratedByUserId,
                ModeratedByUsername = d.ModeratedByUser != null ? d.ModeratedByUser.Username : null,
                ModeratedAt = d.ModeratedAt,
                RejectionReason = d.RejectionReason,
                Tags = d.DestinationTags
                    .Select(dt => new TagRef { Id = dt.TagId, Name = dt.Tag.Name })
                    .ToList(),
                Images = d.Images
                    .OrderBy(i => i.SortOrder)
                    .Select(i => new DestinationImageResponse
                    {
                        Id = i.Id,
                        ContentType = i.ContentType,
                        SortOrder = i.SortOrder
                    })
                    .ToList(),
                PrimaryThumbnail = d.Images
                    .OrderBy(i => i.SortOrder)
                    .Select(i => i.ThumbnailData)
                    .FirstOrDefault(),
                CreatedAt = d.CreatedAt,
                ModifiedAt = d.ModifiedAt
            });

        private async Task<DestinationResponse> RequireResponseAsync(int id)
        {
            var response = await ProjectToResponse(_dbContext.Destinations.AsNoTracking().Where(d => d.Id == id))
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Destination", id);
            FinalizeThumbnail(response);
            return response;
        }

        // Thumbnails are always JPEG (the generator guarantees it), so the content type is a constant set
        // after materialization rather than projected from the stored (original-format) column.
        private static void FinalizeThumbnails(IEnumerable<DestinationResponse> items)
        {
            foreach (var item in items)
            {
                FinalizeThumbnail(item);
            }
        }

        private static void FinalizeThumbnail(DestinationResponse item)
            => item.PrimaryThumbnailContentType = item.PrimaryThumbnail is { Length: > 0 } ? ThumbnailContentType : null;

        private async Task EnsureReferencesExistAsync(int categoryId, int cityId, IEnumerable<int> tagIds)
        {
            if (!await _dbContext.DestinationCategories.AnyAsync(c => c.Id == categoryId))
            {
                throw new BusinessRuleException("The selected category does not exist.");
            }

            if (!await _dbContext.Cities.AnyAsync(c => c.Id == cityId))
            {
                throw new BusinessRuleException("The selected city does not exist.");
            }

            var distinctTagIds = tagIds.Distinct().ToList();
            if (distinctTagIds.Count > 0
                && await _dbContext.Tags.CountAsync(t => distinctTagIds.Contains(t.Id)) != distinctTagIds.Count)
            {
                throw new BusinessRuleException("One or more selected tags do not exist.");
            }
        }

        // Validates the declared type against the real bytes (magic bytes, not the header) then generates
        // the stored thumbnail — the client never supplies one (rule 3 / course §I).
        private async Task<DestinationImage> BuildImageAsync(byte[]? data, string? contentType, int sortOrder)
        {
            if (!FileSignatureValidator.IsValid(data, contentType, FileSignatureValidator.ImageContentTypes))
            {
                throw new BusinessRuleException("Each image must be a valid JPEG or PNG file.");
            }

            var (thumbnail, _) = await _thumbnailGenerator.GenerateThumbnailAsync(data!);

            return new DestinationImage
            {
                ImageData = data!,
                ThumbnailData = thumbnail,
                ContentType = contentType!.Trim(),
                SortOrder = sortOrder
            };
        }

        private static void ReconcileTags(Destination destination, IEnumerable<int> tagIds)
        {
            var desired = tagIds.Distinct().ToHashSet();
            var existing = destination.DestinationTags.Select(dt => dt.TagId).ToHashSet();

            foreach (var link in destination.DestinationTags.Where(dt => !desired.Contains(dt.TagId)).ToList())
            {
                destination.DestinationTags.Remove(link);
            }

            foreach (var tagId in desired.Where(t => !existing.Contains(t)))
            {
                destination.DestinationTags.Add(new DestinationTag { TagId = tagId });
            }
        }

        private async Task ReconcileImagesAsync(Destination destination, List<DestinationImageEditItem> items)
        {
            var keepIds = items.Where(i => i.Id.HasValue).Select(i => i.Id!.Value).ToHashSet();

            // Remove images the edit dropped (cascade delete via the collection).
            foreach (var image in destination.Images.Where(img => !keepIds.Contains(img.Id)).ToList())
            {
                destination.Images.Remove(image);
            }

            // Apply the new order to kept images.
            foreach (var item in items.Where(i => i.Id.HasValue))
            {
                var image = destination.Images.FirstOrDefault(img => img.Id == item.Id!.Value)
                    ?? throw new BusinessRuleException("One or more images to keep no longer exist.");
                image.SortOrder = item.SortOrder;
            }

            // Add newly attached images (validated + thumbnailed).
            foreach (var item in items.Where(i => !i.Id.HasValue))
            {
                destination.Images.Add(await BuildImageAsync(item.Data, item.ContentType, item.SortOrder));
            }
        }

        // Maps a free-text search to the category/tag it names (if any) so the recommender scorer can use
        // it without re-parsing text (03 §15). Stores whichever it resolves alongside the raw term.
        private async Task RecordSearchInteractionAsync(string text, int? explicitCategoryId)
        {
            var userId = _currentUser.GetUserId();
            if (userId is null)
            {
                return;
            }

            int? categoryId = explicitCategoryId
                ?? await _dbContext.DestinationCategories
                    .Where(c => EF.Functions.Collate(c.Name, SearchCollation.CaseInsensitiveAccentInsensitive) == text)
                    .Select(c => (int?)c.Id)
                    .FirstOrDefaultAsync();

            int? tagId = categoryId is not null
                ? null
                : await _dbContext.Tags
                    .Where(t => EF.Functions.Collate(t.Name, SearchCollation.CaseInsensitiveAccentInsensitive) == text)
                    .Select(t => (int?)t.Id)
                    .FirstOrDefaultAsync();

            _dbContext.UserInteractions.Add(new UserInteraction
            {
                UserId = userId.Value,
                InteractionType = InteractionType.Search,
                Weight = _recommenderOptions.Weights.Search,
                SearchTerm = text,
                CategoryId = categoryId,
                TagId = tagId
            });
            await _dbContext.SaveChangesAsync();
        }

        private static void EnsurePending(Destination destination)
        {
            if (destination.Status != DestinationStatus.Pending)
            {
                throw new BusinessRuleException("This destination has already been moderated.");
            }
        }

        // INTERIM: the Notifications service + SignalR push arrive in Phase 9. The in-app row is written
        // directly here so moderation decisions are recorded and visible now; route it through the
        // notification pipeline (real-time push + email) once that lands. See travle-notifications-deferred.
        private void AddModerationNotification(int userId, NotificationType type, string title, string text, int relatedEntityId)
        {
            _dbContext.Notifications.Add(new Notification
            {
                UserId = userId,
                Type = type,
                Title = title,
                Text = text,
                RelatedEntityId = relatedEntityId,
                IsRead = false
            });
        }
    }
}
