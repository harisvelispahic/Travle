using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IDestinationCategoryService
        : IBaseCRUDService<DestinationCategoryResponse, DestinationCategorySearch, DestinationCategoryInsertRequest, DestinationCategoryUpdateRequest>
    {
    }
}
