using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services.Database;
using Humanizer;
using MapsterMapper;
using Microsoft.Extensions.DependencyInjection;


namespace Travle.Services.ProductStateMachine
{   
    public class BaseProductState
    {
        protected TravleDbContext DbContext { get; }
        protected IMapper Mapper { get; }
        protected IServiceProvider ServiceProvider { get; }

        public BaseProductState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
        {
            DbContext = dbContext;
            Mapper = mapper;
            ServiceProvider = serviceProvider;
        }

        public virtual Task<ProductResponse> InsertAsync(ProductInsertRequest request)
        {
            throw new InvalidOperationException("Cannot insert a product in its current state.");
        }

        public virtual Task<ProductResponse> UpdateAsync(int id, ProductUpdateRequest request)
        {
            throw new InvalidOperationException("Cannot update a product in its current state.");
        }

        public virtual Task<ProductResponse> ActivateAsync(int id)
        {
            throw new InvalidOperationException("Cannot activate a product in its current state.");
        }

        public virtual Task<ProductResponse> DeactivateAsync(int id)
        {
            throw new InvalidOperationException("Cannot deactivate a product in its current state.");
        }

        public virtual Task<ProductResponse> DeleteAsync(int id)
        {
            throw new InvalidOperationException("Cannot delete a product in its current state.");
        }

        public BaseProductState GetProductState(string stateName)
        {
            switch (stateName)
            {
                case nameof(InitialProductState):
                    return ServiceProvider.GetService<InitialProductState>()!;
                case nameof(DraftProductState):
                    return ServiceProvider.GetService<DraftProductState>()!;
                case nameof(ActiveProductState):
                    return ServiceProvider.GetService<ActiveProductState>()!;
                // Add cases for other states as needed
                default:
                    throw new InvalidOperationException($"Unknown product state: {stateName}");
            }
        }

        public virtual List<string> GetAllowedActions()
        {
            var allowedActions = new List<string>(); 
            return allowedActions;
        }

    }
}