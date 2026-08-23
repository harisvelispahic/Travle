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
    public class TagService
        : ReferenceCrudService<Tag, TagResponse, TagSearch, TagInsertRequest, TagUpdateRequest>,
          ITagService
    {
        public TagService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<TagInsertRequest> insertValidator,
            IValidator<TagUpdateRequest> updateValidator,
            IAppAuthorizationService authorization)
            : base(dbContext, mapper, insertValidator, updateValidator, authorization)
        {
        }

        private static string BlockedReason(string name, int destinationCount, int interactionCount)
            => $"Cannot delete tag '{name}': it is referenced by {destinationCount} destination(s) and "
               + $"{interactionCount} recorded interaction(s).";

        // Projected list read: usage = tagged destinations + recorded recommender interactions.
        public override Task<PageResult<TagResponse>> GetAllAsync(TagSearch? search = null)
            => GetPageAsync(
                search,
                t => new TagResponse
                {
                    Id = t.Id,
                    Name = t.Name,
                    UsageCount = _dbContext.DestinationTags.Count(dt => dt.TagId == t.Id)
                                 + _dbContext.UserInteractions.Count(i => i.TagId == t.Id),
                    CreatedAt = t.CreatedAt,
                    ModifiedAt = t.ModifiedAt
                },
                row => row.DeleteBlockedReason = row.UsageCount == 0
                    ? null
                    : $"Cannot delete tag '{row.Name}': it is still referenced by "
                      + $"{row.UsageCount} other record(s).");

        protected override IQueryable<Tag> ApplyFilters(IQueryable<Tag> query, TagSearch? search)
        {
            query = query.WhereContains(search?.Name, t => t.Name);

            return query;
        }

        protected override async Task OnBeforeInsertAsync(TagInsertRequest request, Tag entity)
        {
            if (await _dbContext.Tags.AnyAsync(t => t.Name == request.Name))
            {
                throw new ConflictException($"A tag named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeUpdateAsync(int id, TagUpdateRequest request, Tag entity)
        {
            if (await _dbContext.Tags.AnyAsync(t => t.Name == request.Name && t.Id != id))
            {
                throw new ConflictException($"A tag named '{request.Name}' already exists.");
            }
        }

        protected override async Task OnBeforeDeleteAsync(Tag entity)
        {
            int destinationCount = await _dbContext.DestinationTags.CountAsync(dt => dt.TagId == entity.Id);
            int interactionCount = await _dbContext.UserInteractions.CountAsync(i => i.TagId == entity.Id);

            if (destinationCount > 0 || interactionCount > 0)
            {
                throw new ConflictException(BlockedReason(entity.Name, destinationCount, interactionCount));
            }
        }
    }
}
