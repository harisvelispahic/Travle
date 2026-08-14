using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface IDestinationCategoryService
        : IBaseCRUDService<DestinationCategoryResponse, DestinationCategorySearch, DestinationCategoryInsertRequest, DestinationCategoryUpdateRequest>
    {
        /// <summary>Full illustration bytes + content type for the dedicated image endpoint; 404 when unset.</summary>
        Task<(byte[] Content, string ContentType)> GetImageAsync(int id);
    }
}
