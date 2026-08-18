using Travle.Model.Constants;
using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Imaging;
using Travle.Services.Notifications;
using Travle.Services.Projections;
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
        private readonly IAppAuthorizationService _authorization;
        private readonly IAuthenticatedUserAccessor _currentUser;
        private readonly IThumbnailGenerator _thumbnailGenerator;
        private readonly RecommenderOptions _recommenderOptions;
        private readonly INotificationDispatcher _notifications;
        private readonly IValidator<DestinationRejectRequest> _rejectValidator;
        private readonly IValidator<DestinationMapSearch> _mapSearchValidator;

        /// <summary>Upper bound on markers returned by the map endpoint — keeps the payload light and the map
        /// readable; when a wide view holds more, the best-rated survive the cap (see the ordering).</summary>
        private const int MaxMapPins = 100;

        /// <summary>Shortest term the autocomplete acts on — a 1-char probe matches nearly everything, so a
        /// shorter term returns nothing (the mobile client debounces to the same floor).</summary>
        private const int MinSuggestionChars = 2;

        /// <summary>Upper bound on autocomplete rows — a short, scannable typeahead list, best-rated first.
        /// It stays capped (the spec calls for "capped suggestions"); the full match set is one submit away
        /// on the paginated results list.</summary>
        private const int MaxSuggestions = 12;

        public DestinationService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IAppAuthorizationService authorization,
            IAuthenticatedUserAccessor currentUser,
            IThumbnailGenerator thumbnailGenerator,
            IOptions<RecommenderOptions> recommenderOptions,
            INotificationDispatcher notifications,
            IValidator<DestinationInsertRequest> insertValidator,
            IValidator<DestinationUpdateRequest> updateValidator,
            IValidator<DestinationRejectRequest> rejectValidator,
            IValidator<DestinationMapSearch> mapSearchValidator)
            : base(dbContext, mapper, insertValidator, updateValidator)
        {
            _authorization = authorization;
            _currentUser = currentUser;
            _thumbnailGenerator = thumbnailGenerator;
            _recommenderOptions = recommenderOptions.Value;
            _notifications = notifications;
            _rejectValidator = rejectValidator;
            _mapSearchValidator = mapSearchValidator;
        }

        protected override IQueryable<Destination> ApplyFilters(IQueryable<Destination> query, DestinationSearch? search)
        {
            if (search is null)
            {
                return query;
            }

            // Accent-aware name/description search: plain terms match accent-insensitively, an accented term
            // stays accent-sensitive (see TextSearch / SearchCollation).
            query = query.WhereContains(search.Text, d => d.Name, d => d.Description);

            if (search.CategoryId.HasValue)
            {
                query = query.Where(d => d.CategoryId == search.CategoryId.Value);
            }

            if (search.CountryId.HasValue)
            {
                query = query.Where(d => d.City.Region.CountryId == search.CountryId.Value);
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
                // Match on the computed rating shown to users (suspended authors excluded), not the
                // denormalized column, so the filter agrees with the rating on the card.
                query = DestinationProjections.WhereMinRating(query, search.MinRating.Value);
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

            var items = await DestinationProjections.ProjectToResponse(query).ToListAsync();
            DestinationProjections.FinalizeThumbnails(items);
            await ApplyFavoriteFlagsAsync(items);

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

        public async Task<List<DestinationMapPinResponse>> GetMapPinsAsync(DestinationMapSearch search)
        {
            await _mapSearchValidator.ValidateAndThrowAsync(search);

            // Only the published catalogue appears on the map, and only within the visible box — the bbox
            // filter runs in SQL (never client-side). Validation guarantees the four edges are present.
            var query = _dbContext.Destinations
                .AsNoTracking()
                .Where(d => d.Status == DestinationStatus.Approved)
                .Where(d => d.Latitude >= search.South!.Value && d.Latitude <= search.North!.Value)
                .Where(d => d.Longitude >= search.West!.Value && d.Longitude <= search.East!.Value);

            if (search.CategoryIds is { Count: > 0 })
            {
                query = query.Where(d => search.CategoryIds.Contains(d.CategoryId));
            }

            // Filter on the computed rating (the value the marker shows), not the denormalized column, so a
            // "3+ stars" filter never hides a card that displays 4.0 (see WhereMinRating).
            if (search.MinRating.HasValue)
            {
                query = DestinationProjections.WhereMinRating(query, search.MinRating.Value);
            }

            // The map is a pan-heavy browse surface: recording a Search interaction on each bbox fetch would
            // flood the recommender diary (every pan while a category is selected), so it records nothing —
            // category interest is captured by the text/category Search screen instead.

            // Cap the payload; when the box holds more than the cap, the best-rated markers survive it.
            query = query
                .OrderByDescending(d => d.AverageRating)
                .ThenBy(d => d.Id)
                .Take(MaxMapPins);

            var items = await DestinationProjections.ProjectToMapPin(query).ToListAsync();
            DestinationProjections.FinalizeMapPinThumbnails(items);
            return items;
        }

        public async Task<List<DestinationSuggestionResponse>> GetSuggestionsAsync(string? text)
        {
            var term = text?.Trim();
            // A typeahead probes on every keystroke; a term below the floor isn't a client error, it's just
            // too broad to suggest on, so hand back an empty list (never a validation exception).
            if (string.IsNullOrEmpty(term) || term.Length < MinSuggestionChars)
            {
                return new List<DestinationSuggestionResponse>();
            }

            // Approved-only, accent-aware name match (WhereContains: "Poc" matches "Počitelj"), best-rated
            // first, capped. Records no interaction — the genuine Search signal is written when the user
            // submits the full search from a picked suggestion.
            var query = _dbContext.Destinations
                .AsNoTracking()
                .Where(d => d.Status == DestinationStatus.Approved)
                .WhereContains(term, d => d.Name)
                .OrderByDescending(d => d.AverageRating)
                .ThenBy(d => d.Name)
                .ThenBy(d => d.Id)
                .Take(MaxSuggestions);

            return await DestinationProjections.ProjectToSuggestion(query).ToListAsync();
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

            // A pending/rejected destination is only ever visible to its submitter or an admin. Approved
            // destinations are public to any authenticated user; anything else must not be reachable — not
            // through a tour that visits it, nor by guessing its id (the moderation catalogue stays private).
            if (meta.Status != DestinationStatus.Approved)
            {
                _authorization.EnsureSelfOrAdmin(meta.SubmittedByUserId, "destination");
            }

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

            // Destination (with its images/tags) + admin "awaiting moderation" notifications commit together
            // (two SaveChanges → one transaction, rule 7): the first save assigns the id they deep-link to.
            await using var transaction = await _dbContext.Database.BeginTransactionAsync();
            await _dbContext.SaveChangesAsync();
            await NotifyAdminsOfSubmissionAsync(destination.Name, destination.Id);
            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();

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

            // Whether this edit is bringing the destination back into the moderation queue from a decided
            // state — captured before the status is reset, so admins are only re-notified on a real re-entry
            // (not on repeated edits of an already-pending one). wasApproved additionally distinguishes the
            // case where the destination is leaving the *published* catalogue, which ripples to any tour
            // built on it (its organizer must be told). The editor is excluded from that fan-out.
            var wasPending = destination.Status == DestinationStatus.Pending;
            var wasApproved = destination.Status == DestinationStatus.Approved;
            var editorId = _authorization.RequireUserId();

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

            // Re-entering the queue from an approved/rejected state notifies the admins; the notifications are
            // staged onto the same SaveChanges as the edit, so they commit atomically with it.
            if (!wasPending)
            {
                await NotifyAdminsOfSubmissionAsync(destination.Name, id);
            }

            // Leaving the published catalogue (approved → back to pending) affects every organizer whose tour
            // visits this destination — their itinerary now has a stop travelers can't see until it's approved
            // again. Tell them (never the editor themselves).
            if (wasApproved)
            {
                await NotifyOrganizersOfDestinationAvailabilityAsync(id,
                    NotificationType.DestinationUnavailable,
                    "A destination on your tour is unavailable",
                    $"A destination one of your tours visits, '{destination.Name}', was edited and is awaiting re-approval, so it is temporarily hidden from travelers.",
                    excludeUserId: editorId);
            }

            // All reconciliation (and any admin/organizer notifications) is tracked in one SaveChanges → one transaction.
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

            // If an admin removed someone else's pending submission, tell the submitter (they didn't do it,
            // and their draft is now gone). Self-deletion is silent — the curator just did it themselves.
            var actingUserId = _authorization.RequireUserId();
            if (actingUserId != destination.SubmittedByUserId)
            {
                _notifications.Enqueue(destination.SubmittedByUserId, NotificationType.General,
                    "Destination removed",
                    $"Your pending destination '{destination.Name}' was removed by an administrator.",
                    relatedEntityId: null);
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

            // If this approval brings a destination back that tours already reference (it can only carry tour
            // references if it was approved before, then edited to Pending), tell those organizers their
            // itinerary is whole again. Empty (a no-op) for a first-time approval, which no tour can reference.
            await NotifyOrganizersOfDestinationAvailabilityAsync(id,
                NotificationType.DestinationAvailable,
                "A destination on your tour is available again",
                $"A destination one of your tours visits, '{destination.Name}', has been re-approved and is visible to travelers again.",
                excludeUserId: null);

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

            // Being featured is a promotion the curator will want to hear about (it drives their traffic).
            // Only on featuring — un-featuring is an internal editorial call, not news for the submitter.
            if (isFeatured)
            {
                _notifications.Enqueue(destination.SubmittedByUserId, NotificationType.DestinationFeatured,
                    "Your destination was featured",
                    $"Great news — your destination '{destination.Name}' has been featured on Travle.",
                    destination.Id);
            }

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

        // The single Destination → response projection lives in DestinationProjections (shared with the
        // favorites service); reads here add the per-user favorite flag after materialization.
        private async Task<DestinationResponse> RequireResponseAsync(int id)
        {
            var response = await DestinationProjections
                .ProjectToResponse(_dbContext.Destinations.AsNoTracking().Where(d => d.Id == id))
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException("Destination", id);
            DestinationProjections.FinalizeThumbnail(response);
            await ApplyFavoriteFlagsAsync(new[] { response });
            return response;
        }

        // Sets IsFavorite for the current user across a page in one batch query (no N+1). Anonymous callers
        // and empty pages short-circuit — nothing is favorited.
        private async Task ApplyFavoriteFlagsAsync(IReadOnlyCollection<DestinationResponse> items)
        {
            var userId = _currentUser.GetUserId();
            if (userId is null || items.Count == 0)
            {
                return;
            }

            var ids = items.Select(i => i.Id).ToList();
            var favoritedIds = (await _dbContext.Favorites
                    .Where(f => f.UserId == userId.Value && f.DestinationId != null && ids.Contains(f.DestinationId.Value))
                    .Select(f => f.DestinationId!.Value)
                    .ToListAsync())
                .ToHashSet();

            foreach (var item in items)
            {
                item.IsFavorite = favoritedIds.Contains(item.Id);
            }
        }

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

        // Curator-facing moderation decision (approve/reject). Staged for the caller's SaveChanges so it
        // commits with the decision; the SignalR push and the email fire on the post-commit flush. Both
        // decisions email the submitter (spec §5 "status changes").
        private void AddModerationNotification(int userId, NotificationType type, string title, string text, int relatedEntityId)
            => _notifications.Enqueue(userId, type, title, text, relatedEntityId, alsoEmail: true);

        // Fan-out to every admin that a destination is (re-)entering the moderation queue.
        private async Task NotifyAdminsOfSubmissionAsync(string destinationName, int destinationId)
        {
            var adminIds = await NotificationRecipients.AdminUserIdsAsync(_dbContext);
            foreach (var adminId in adminIds)
            {
                _notifications.Enqueue(adminId, NotificationType.DestinationSubmitted,
                    "Destination awaiting moderation",
                    $"'{destinationName}' was submitted and is awaiting moderation.",
                    destinationId);
            }
        }

        // Fan-out to the distinct organizers whose tours include this destination — used when it leaves
        // (DestinationUnavailable) or re-enters (DestinationAvailable) the published catalogue, since either
        // ripples to their live itineraries. Empty for a destination no tour uses (e.g. a first-time
        // approval). Staged (unsaved) for the caller's SaveChanges, like the admin fan-out above.
        private async Task NotifyOrganizersOfDestinationAvailabilityAsync(
            int destinationId, NotificationType type, string title, string text, int? excludeUserId)
        {
            var organizerIds = await _dbContext.TourDestinations
                .Where(td => td.DestinationId == destinationId)
                .Select(td => td.Tour.OrganizerId)
                .Distinct()
                .ToListAsync();

            foreach (var organizerId in organizerIds)
            {
                if (excludeUserId.HasValue && organizerId == excludeUserId.Value)
                {
                    continue;
                }
                _notifications.Enqueue(organizerId, type, title, text, destinationId);
            }
        }
    }
}
