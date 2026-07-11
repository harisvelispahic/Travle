using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IProductService : IBaseCRUDService<ProductResponse, ProductSearchObject, ProductInsertRequest, ProductUpdateRequest>
    {
        Task<ProductResponse> ActivateAsync(int id);
        Task<ProductResponse> DeactivateAsync(int id);

        Task<List<string>> GetAllowedActionsAsync(int id);
    }
}