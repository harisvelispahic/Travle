using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class DestinationCategoryUpdateValidator : AbstractValidator<DestinationCategoryUpdateRequest>
    {
        public DestinationCategoryUpdateValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Category name is required.")
                .MaximumLength(100).WithMessage("Category name cannot exceed 100 characters.");
        }
    }
}
