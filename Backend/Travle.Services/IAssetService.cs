using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Travle.Services
{
    public interface IAssetService : IBaseCRUDService<AssetResponse, AssetSearch, AssetInsertRequest, AssetUpdateRequest>
    {
    }
}
