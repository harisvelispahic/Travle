using Travle.Model.SearchObjects;
using Travle.Services.Database;
using FluentValidation;
using FluentValidation.Results;
using Mapster;
using MapsterMapper;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Travle.Services
{
    /// <summary>
    /// Generic base service for CRUD operations (Create, Read, Update, Delete)
    /// </summary>
    public abstract class BaseCRUDService<TEntity, TResponse, TSearch, TInsertRequest, TUpdateRequest>
        : BaseReadService<TEntity, TResponse, TSearch>
        where TEntity : class
        where TSearch : BaseSearchObject
    {

        protected readonly IValidator<TInsertRequest> _insertValidator;
        protected readonly IValidator<TUpdateRequest> _updateValidator;

        protected BaseCRUDService(TravleDbContext dbContext, MapsterMapper.IMapper mapper, IValidator<TInsertRequest> insertValidator, IValidator<TUpdateRequest> updateValidator) : base(mapper, dbContext)
        {
            _insertValidator = insertValidator;
            _updateValidator = updateValidator;
        }

        /// <summary>
        /// Gets a writable data source for CRUD operations. Override in derived classes.
        /// </summary>


        /// <summary>
        /// Maps an insert request to an entity. Override in derived classes for custom logic.
        /// </summary>
        protected virtual TEntity MapInsertRequestToEntity(TInsertRequest request)
        {
            var entity = _mapper.Map<TEntity>(request ?? throw new ArgumentNullException(nameof(request)));
            return entity;
        }

        /// <summary>
        /// Maps an update request to an existing entity. Override in derived classes for custom logic.
        /// </summary>
        protected virtual void MapUpdateRequestToEntity(TUpdateRequest request, TEntity entity)
        {
            // var config = new TypeAdapterConfig();
            // config.NewConfig<TUpdateRequest, TEntity>()
            //     .IgnoreNullValues(true);
            // new Mapper(config).Map(request, entity);
            _mapper.Map(request, entity);
        }

        /// <summary>
        /// Inserts a new entity into the data source.
        /// </summary>
        public virtual async Task<TResponse> InsertAsync(TInsertRequest request)
        {
            var validationResult = await _insertValidator.ValidateAsync(request);
            if (validationResult.IsValid == false)
            {
                var errors = validationResult.Errors.Select(e => _mapper.Map<ValidationFailure>(e));
                throw new FluentValidation.ValidationException(errors);
            }

            var entity = MapInsertRequestToEntity(request);

            // Set the Id property
            var entityType = entity.GetType();
            var idProperty = entityType.GetProperty("Id");
            //idProperty?.SetValue(entity, GenerateNewId());

            // Set CreatedAt if exists
            var createdAtProperty = entityType.GetProperty("CreatedAt");
            if (createdAtProperty?.CanWrite == true)
            {
                createdAtProperty.SetValue(entity, DateTime.UtcNow);
            }

            this._dbContext.Set<TEntity>().Add(entity);
            await this._dbContext.SaveChangesAsync();
            
            return await Task.FromResult(_mapper.Map<TResponse>(entity));
        }

        /// <summary>
        /// Updates an existing entity in the data source.
        /// </summary>
        public virtual async Task<TResponse> UpdateAsync(int id, TUpdateRequest request)
        {
            var validationResult = await _updateValidator.ValidateAsync(request);
            if (validationResult.IsValid == false)
            {
                var errors = validationResult.Errors.Select(e => _mapper.Map<ValidationFailure>(e));
                throw new FluentValidation.ValidationException(errors);
            }

           
            var entity = this._dbContext.Set<TEntity>().Find(id);

            if (entity == null)
                throw new KeyNotFoundException($"{typeof(TEntity).Name} with id {id} not found.");

            MapUpdateRequestToEntity(request, entity);

            // Update the UpdatedAt timestamp
            var updatedAtProperty = entity.GetType().GetProperty("UpdatedAt");
            if (updatedAtProperty?.CanWrite == true)
            {
                updatedAtProperty.SetValue(entity, DateTime.UtcNow);
            }

            await this._dbContext.SaveChangesAsync();

            return await Task.FromResult(_mapper.Map<TResponse>(entity));
        }

        /// <summary>
        /// Deletes an entity from the data source by id.
        /// </summary>
        public virtual async Task DeleteAsync(int id)
        {
            var entity = this._dbContext.Set<TEntity>().Find(id);

            if (entity == null)
                throw new KeyNotFoundException($"{typeof(TEntity).Name} with id {id} not found.");

            this._dbContext.Set<TEntity>().Remove(entity);
            await this._dbContext.SaveChangesAsync();
        }
    }
}
