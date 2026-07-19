using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    public interface ITourTypeService
        : IBaseCRUDService<TourTypeResponse, TourTypeSearch, TourTypeInsertRequest, TourTypeUpdateRequest>
    {
    }
}
