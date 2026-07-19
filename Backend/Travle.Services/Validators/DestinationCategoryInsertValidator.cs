using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class DestinationCategoryInsertValidator : AbstractValidator<DestinationCategoryInsertRequest>
    {
        public DestinationCategoryInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Category name is required.")
                .MaximumLength(100).WithMessage("Category name cannot exceed 100 characters.");
        }
    }
}
