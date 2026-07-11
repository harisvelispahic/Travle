using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators;

public class ProductReviewUpdateValidator : AbstractValidator<ProductReviewUpdateRequest>
{
    public ProductReviewUpdateValidator()
    {
        RuleFor(x => x.Rating).InclusiveBetween(1, 5);
        RuleFor(x => x.Comment).MaximumLength(1000);
    }
}
