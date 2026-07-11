using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

[Authorize]
public class ProductReviewsController
    : BaseCRUDController<ProductReviewResponse, ProductReviewSearchObject, ProductReviewInsertRequest, ProductReviewUpdateRequest, IProductReviewService>
{
    public ProductReviewsController(IProductReviewService productReviewService)
        : base(productReviewService)
    {
    }
}
