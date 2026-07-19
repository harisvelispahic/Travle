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

        /// <summary>
        /// Business-rule hook invoked after field validation and mapping but before the insert is saved.
        /// Override to enforce cross-row rules the FluentValidation validator cannot express without the
        /// database — e.g. uniqueness or the existence of a referenced parent — throwing the appropriate
        /// <c>TravleException</c> (usually <see cref="ConflictException"/> or
        /// <see cref="BusinessRuleException"/>). Default: no-op.
        /// </summary>
        protected virtual Task OnBeforeInsertAsync(TInsertRequest request, TEntity entity) => Task.CompletedTask;

        /// <summary>
        /// Business-rule hook invoked after the entity is loaded and validated but before the update is
        /// mapped and saved. Override for uniqueness/parent-existence checks (excluding the row itself).
        /// Default: no-op.
        /// </summary>
        protected virtual Task OnBeforeUpdateAsync(int id, TUpdateRequest request, TEntity entity) => Task.CompletedTask;

        /// <summary>
        /// Business-rule hook invoked after the entity is loaded but before it is removed. Override to
        /// block deletion of reference data that is still in use, surfacing a counted
        /// <see cref="ConflictException"/> (03 §3 delete strategy). Default: no-op.
        /// </summary>
        protected virtual Task OnBeforeDeleteAsync(TEntity entity) => Task.CompletedTask;

        public virtual async Task<TResponse> InsertAsync(TInsertRequest request)
        {
            // ValidateAndThrowAsync raises a ValidationException, which the ValidationExceptionHandler
            // turns into the standard 400 ErrorResponse.
            await _insertValidator.ValidateAndThrowAsync(request);

            var entity = MapInsertRequestToEntity(request);

            await OnBeforeInsertAsync(request, entity);

            _dbContext.Set<TEntity>().Add(entity);
            await _dbContext.SaveChangesAsync();

            // Only the FK was set during mapping; load the response's navigations (e.g. the parent whose
            // name the DTO flattens) so a created entity comes back with the same shape as a fetched one.
            await LoadResponseNavigationsAsync(entity);

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

            await OnBeforeUpdateAsync(id, request, entity);

            MapUpdateRequestToEntity(request, entity);
            await _dbContext.SaveChangesAsync();

            // Reload the response's navigations (the update loaded the row without includes, and the FK
            // may have changed) so the flattened parent name reflects the saved state.
            await LoadResponseNavigationsAsync(entity);

            return _mapper.Map<TResponse>(entity);
        }

        public virtual async Task DeleteAsync(int id)
        {
            var entity = await _dbContext.Set<TEntity>().FindAsync(id);
            if (entity is null)
            {
                throw new NotFoundException(typeof(TEntity).Name, id);
            }

            await OnBeforeDeleteAsync(entity);

            _dbContext.Set<TEntity>().Remove(entity);
            await _dbContext.SaveChangesAsync();
        }
    }
}
