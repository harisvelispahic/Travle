using Travle.Model.Exceptions;
using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Authorization;
using Travle.Services.Database;
using Travle.Services.Imaging;
using Travle.Services.Security;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace Travle.Services
{
    public class DestinationCategoryService
        : ReferenceCrudService<DestinationCategory, DestinationCategoryResponse, DestinationCategorySearch, DestinationCategoryInsertRequest, DestinationCategoryUpdateRequest>,
          IDestinationCategoryService
    {
        /// <summary>Upper bound on an uploaded category illustration (mirrors the profile-image limit).</summary>
        private const int MaxImageBytes = 5 * 1024 * 1024;

        private readonly IThumbnailGenerator _thumbnailGenerator;

        public DestinationCategoryService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<DestinationCategoryInsertRequest> insertValidator,
            IValidator<DestinationCategoryUpdateRequest> updateValidator,
            IAppAuthorizationService authorization,
            IThumbnailGenerator thumbnailGenerator)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
            _thumbnailGenerator = thumbnailGenerator;
        }

        protected override IQueryable<DestinationCategory> ApplyFilters(IQueryable<DestinationCategory> query, DestinationCategorySearch? search)
        {
            query = query.WhereContains(search?.Name, c => c.Name);

            return query;
        }

        // The list projection deliberately excludes the heavy full Image bytes — only the small
        // ImageThumbnail rides along (rule 12). This override is needed because the generic base loads whole
        // entities into memory before mapping, which would otherwise drag every category's full blob.
        /// <summary>The one sentence used both as the disabled-Delete reason and as the conflict message.</summary>
        private static string BlockedReason(string name, int destinationCount, int interactionCount)
            => $"Cannot delete category '{name}': it is referenced by {destinationCount} destination(s) and "
               + $"{interactionCount} recorded interaction(s).";

        public override Task<PageResult<DestinationCategoryResponse>> GetAllAsync(DestinationCategorySearch? search = null)
            => GetPageAsync(
                search,
                c => new DestinationCategoryResponse
                {
                    Id = c.Id,
                    Name = c.Name,
                    Description = c.Description,
                    // Thumbnail only — the full Image bytes are intentionally never selected here.
                    ImageThumbnail = c.ImageThumbnail,
                    UsageCount = _dbContext.Destinations.Count(d => d.CategoryId == c.Id)
                                 + _dbContext.UserInteractions.Count(i => i.CategoryId == c.Id),
                    CreatedAt = c.CreatedAt,
                    ModifiedAt = c.ModifiedAt
                },
                row => row.DeleteBlockedReason = row.UsageCount == 0
                    ? null
                    : $"Cannot delete category '{row.Name}': it is still referenced by "
                      + $"{row.UsageCount} other record(s).");

        // Name/description are set here; the image is applied in the async OnBefore hooks (validation +
        // thumbnail generation are async and can't run in this synchronous map step). Never let the mapper
        // touch the image members, so an update that omits the image keeps the existing bytes.
        protected override DestinationCategory MapInsertRequestToEntity(DestinationCategoryInsertRequest request)
            => new()
            {
                Name = request.Name,
                Description = NormalizeDescription(request.Description)
            };

        protected override void MapUpdateRequestToEntity(DestinationCategoryUpdateRequest request, DestinationCategory entity)
        {
            entity.Name = request.Name;
            entity.Description = NormalizeDescription(request.Description);
            // Image handled in OnBeforeUpdateAsync; untouched here so a null image preserves the current one.
        }

        protected override async Task OnBeforeInsertAsync(DestinationCategoryInsertRequest request, DestinationCategory entity)
        {
            if (await _dbContext.DestinationCategories.AnyAsync(c => c.Name == request.Name))
            {
                throw new ConflictException($"A category named '{request.Name}' already exists.");
            }

            await ApplyImageAsync(entity, request.Image, request.ImageContentType);
        }

        protected override async Task OnBeforeUpdateAsync(int id, DestinationCategoryUpdateRequest request, DestinationCategory entity)
        {
            if (await _dbContext.DestinationCategories.AnyAsync(c => c.Name == request.Name && c.Id != id))
            {
                throw new ConflictException($"A category named '{request.Name}' already exists.");
            }

            await ApplyImageAsync(entity, request.Image, request.ImageContentType);
        }

        protected override async Task OnBeforeDeleteAsync(DestinationCategory entity)
        {
            int destinationCount = await _dbContext.Destinations.CountAsync(d => d.CategoryId == entity.Id);
            int interactionCount = await _dbContext.UserInteractions.CountAsync(i => i.CategoryId == entity.Id);

            if (destinationCount > 0 || interactionCount > 0)
            {
                throw new ConflictException(BlockedReason(entity.Name, destinationCount, interactionCount));
            }
        }

        /// <summary>Full illustration bytes for the dedicated image endpoint. 404s when the category has none.</summary>
        public async Task<(byte[] Content, string ContentType)> GetImageAsync(int id)
        {
            var image = await _dbContext.DestinationCategories
                .AsNoTracking()
                .Where(c => c.Id == id)
                .Select(c => new { c.Image, c.ImageContentType })
                .FirstOrDefaultAsync()
                ?? throw new NotFoundException(nameof(DestinationCategory), id);

            if (image.Image is null || image.Image.Length == 0 || string.IsNullOrWhiteSpace(image.ImageContentType))
            {
                throw new NotFoundException("Category image", id);
            }

            return (image.Image, image.ImageContentType);
        }

        // Validates and stores a supplied illustration + its generated thumbnail. A null/empty image is a
        // no-op: on insert the category simply has no image; on update the existing image is preserved.
        private async Task ApplyImageAsync(DestinationCategory entity, byte[]? image, string? contentType)
        {
            if (image is null || image.Length == 0)
            {
                return;
            }

            if (image.Length > MaxImageBytes)
            {
                throw new BusinessRuleException("The image is too large. Please upload an image of 5 MB or smaller.");
            }

            // Re-verify the bytes against the declared type by magic bytes — never trust the client (§I).
            if (!FileSignatureValidator.IsValid(image, contentType, FileSignatureValidator.ImageContentTypes))
            {
                throw new BusinessRuleException("The image could not be read. Please upload a valid JPEG or PNG image.");
            }

            var (thumbnail, _) = await _thumbnailGenerator.GeneratePngThumbnailAsync(image);
            entity.Image = image;
            entity.ImageContentType = contentType!.Trim();
            entity.ImageThumbnail = thumbnail;
        }

        private static string? NormalizeDescription(string? description)
            => string.IsNullOrWhiteSpace(description) ? null : description.Trim();
    }
}
