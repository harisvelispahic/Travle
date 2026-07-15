using Travle.Model.Exceptions;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;

namespace Travle.Services
{
    /// <summary>
    /// Generic base service for CRUD operations (Create, Read, Update, Delete). Audit timestamps
    /// (<c>CreatedAt</c>/<c>ModifiedAt</c>) are stamped centrally in <see cref="TravleDbContext"/> on
    /// save — services never set them, and the surrogate key is assigned by the database.
    /// </summary>
    public abstract class BaseCRUDService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseReadService<TEntity, TResponse, TSearch>
        where TEntity : class
        where TSearch : BaseSearchObject
    {
        protected readonly IValidator<TInsertRequest> _insertValidator;
        protected readonly IValidator<TUpdateRequest> _updateValidator;

        protected BaseCRUDService(
            TravleDbContext dbContext,
            MapsterMapper.IMapper mapper,
            IValidator<TInsertRequest> insertValidator,
            IValidator<TUpdateRequest> updateValidator)
            : base(mapper, dbContext)
        {
            _insertValidator = insertValidator;
            _updateValidator = updateValidator;
        }

        /// <summary>
        /// Maps an insert request to a new entity. Override for logic the mapper can't express
        /// (e.g. hashing a password), calling <c>base.MapInsertRequestToEntity</c> first.
        /// </summary>
        protected virtual TEntity MapInsertRequestToEntity(TInsertRequest request)
        {
            ArgumentNullException.ThrowIfNull(request);
            return _mapper.Map<TEntity>(request);
        }

        /// <summary>
        /// Applies an update request onto an already-loaded, tracked entity. Override for custom logic.
        /// </summary>
        protected virtual void MapUpdateRequestToEntity(TUpdateRequest request, TEntity entity)
            => _mapper.Map(request, entity);

        public virtual async Task<TResponse> InsertAsync(TInsertRequest request)
        {
            // ValidateAndThrowAsync raises a ValidationException, which the ValidationExceptionHandler
            // turns into the standard 400 ErrorResponse.
            await _insertValidator.ValidateAndThrowAsync(request);

            var entity = MapInsertRequestToEntity(request);

            _dbContext.Set<TEntity>().Add(entity);
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<TResponse>(entity);
        }

        public virtual async Task<TResponse> UpdateAsync(int id, TUpdateRequest request)
        {
            await _updateValidator.ValidateAndThrowAsync(request);

            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity is null)
            {
                throw new NotFoundException(typeof(TEntity).Name, id);
            }

            MapUpdateRequestToEntity(request, entity);
            await _dbContext.SaveChangesAsync();

            return _mapper.Map<TResponse>(entity);
        }

        public virtual async Task DeleteAsync(int id)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity is null)
            {
                throw new NotFoundException(typeof(TEntity).Name, id);
            }

            _dbContext.Set<TEntity>().Remove(entity);
            await _dbContext.SaveChangesAsync();
        }
    }
}
