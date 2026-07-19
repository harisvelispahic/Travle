using Travle.Model.Exceptions;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;
using System.Linq.Dynamic.Core;
using System.Linq.Dynamic.Core.Exceptions;

namespace Travle.Services
{
    /// <summary>
    /// Generic base for read-only services. Every stage (filter, sort, page, project) is composed on
    /// an <see cref="IQueryable{T}"/> so it is translated to SQL and evaluated in the database — the
    /// set is never pulled into memory to be filtered client-side.
    /// </summary>
    public abstract class BaseReadService<TEntity, TResponse, TSearch> : IBaseReadService<TResponse, TSearch>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        protected readonly MapsterMapper.IMapper _mapper;
        protected readonly TravleDbContext _dbContext;

        /// <summary>Hard upper bound on page size, enforced regardless of the requested value.</summary>
        protected const int MaxPageSize = 100;

        /// <summary>Page size used when the request does not specify one.</summary>
        protected const int DefaultPageSize = 10;

        protected BaseReadService(MapsterMapper.IMapper mapper, TravleDbContext dbContext)
        {
            _mapper = mapper;
            _dbContext = dbContext;
        }

        public virtual async Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null)
        {
            IQueryable<TEntity> query = _dbContext.Set<TEntity>().AsNoTracking();

            query = ApplyFilters(query, search);

            int? totalCount = null;
            if (search?.IncludeTotalCount ?? false)
            {
                // Counted before includes so COUNT(*) runs over the filtered set without join overhead.
                totalCount = await query.CountAsync();
            }

            query = ApplySorting(query, search);
            query = ApplyPaging(query, search);
            query = ApplyIncludes(query, search);

            var entities = await query.ToListAsync();
            var items = _mapper.Map<List<TResponse>>(entities);

            return new PageResult<TResponse>
            {
                Items = items,
                TotalCount = totalCount
            };
        }

        public virtual async Task<TResponse> GetByIdAsync(int id)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity is null)
            {
                throw new NotFoundException(typeof(TEntity).Name, id);
            }

            await LoadResponseNavigationsAsync(entity);

            return _mapper.Map<TResponse>(entity);
        }

        /// <summary>
        /// Loads navigation properties on a single tracked entity that the response DTO needs — e.g. a
        /// parent whose name the response flattens (<c>Region.Name → RegionName</c>). Override with
        /// <c>_dbContext.Entry(entity).Reference(...).LoadAsync()</c>. This is the single-entity
        /// counterpart of <see cref="ApplyIncludes"/> (which handles the list path as a JOIN): it is
        /// invoked by <see cref="GetByIdAsync"/> and by the CRUD service's Insert/Update, so a created
        /// or updated entity comes back with the same shape as a fetched one — where the mapper only has
        /// the surrogate FK in memory otherwise, the flattened name would be null. Default: no-op.
        /// </summary>
        protected virtual Task LoadResponseNavigationsAsync(TEntity entity) => Task.CompletedTask;

        /// <summary>
        /// Adds search-specific <c>WHERE</c> clauses. Override in derived services. The query must stay
        /// an <see cref="IQueryable{T}"/> so filters translate to SQL — never enumerate it here.
        /// </summary>
        protected virtual IQueryable<TEntity> ApplyFilters(IQueryable<TEntity> query, TSearch? search) => query;

        /// <summary>
        /// Adds <c>Include</c>/<c>ThenInclude</c> for related entities — typically toggled by flags on
        /// the search object so an endpoint can return a lighter or richer graph on demand (e.g. skip
        /// heavy navigations when the caller doesn't need them). Override in derived services; the base
        /// includes nothing. Applied after paging so the count query stays lean and the includes only
        /// hydrate the current page. Synchronous by design: composing an <see cref="IQueryable{T}"/>
        /// never awaits (this replaces the template's misnamed <c>IncludeRelatedEntitiesAsync</c>).
        /// </summary>
        protected virtual IQueryable<TEntity> ApplyIncludes(IQueryable<TEntity> query, TSearch? search) => query;

        /// <summary>
        /// Applies <c>ORDER BY</c> from <see cref="BaseSearchObject.SortBy"/> (a property-name based
        /// dynamic expression, not raw SQL), defaulting to <c>Id</c> so paging is deterministic. An
        /// unparseable expression surfaces as a 400 instead of an unhandled 500.
        /// </summary>
        protected virtual IQueryable<TEntity> ApplySorting(IQueryable<TEntity> query, TSearch? search)
        {
            var sortBy = string.IsNullOrWhiteSpace(search?.SortBy) ? "Id" : search.SortBy;

            try
            {
                return query.OrderBy(sortBy);
            }
            catch (ParseException)
            {
                throw new BusinessRuleException($"Invalid sort expression: '{search?.SortBy}'.");
            }
        }

        /// <summary>
        /// Applies <c>Skip</c>/<c>Take</c>. Paging is always applied and the page size is clamped to
        /// <see cref="MaxPageSize"/> so a list endpoint can never return an unbounded result set.
        /// </summary>
        protected virtual IQueryable<TEntity> ApplyPaging(IQueryable<TEntity> query, TSearch? search)
        {
            int page = search?.Page is int p && p > 0 ? p : 1;

            int pageSize = search?.PageSize ?? DefaultPageSize;
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
