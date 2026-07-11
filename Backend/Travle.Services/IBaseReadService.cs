using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace Travle.Services
{
    public interface IBaseReadService<TResponse, TSearch>
        where TSearch : BaseSearchObject
    {
        Task<TResponse> GetByIdAsync(int id);
        Task<PageResult<TResponse>> GetAllAsync(TSearch? search = null);
    }
}
