using Travle.Services;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Microsoft.AspNetCore.Mvc;
using Travle.Model.Requests;

namespace Travle.WebAPI.Controllers;

public class UnitOfMeasuresController : BaseCRUDController<UnitOfMeasureResponse, UnitOfMeasureSearch, UnitOfMeasureInsertRequest, UnitOfMeasureUpdateRequest, IUnitOfMeasureService>
{
    public UnitOfMeasuresController(IUnitOfMeasureService unitOfMeasureService) : base(unitOfMeasureService)
    {
    }
}
