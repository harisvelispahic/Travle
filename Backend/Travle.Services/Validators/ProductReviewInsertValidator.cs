using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators;

public class ProductReviewInsertValidator : AbstractValidator<ProductReviewInsertRequest>
{
    public ProductReviewInsertValidator()
    {
        RuleFor(x => x.OrderId).GreaterThan(0);
        RuleFor(x => x.ProductId).GreaterThan(0);
        RuleFor(x => x.Rating).InclusiveBetween(1, 5);
        RuleFor(x => x.Comment).MaximumLength(1000);
    }
}
