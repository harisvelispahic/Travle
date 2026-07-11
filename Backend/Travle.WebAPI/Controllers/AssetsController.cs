using Travle.Services;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Microsoft.AspNetCore.Mvc;
using Travle.Model.Requests;

namespace Travle.WebAPI.Controllers;

public class AssetsController : BaseCRUDController<AssetResponse, AssetSearch, AssetInsertRequest, AssetUpdateRequest, IAssetService>
{
    public AssetsController(IAssetService assetService) : base(assetService)
    {
    }
}
