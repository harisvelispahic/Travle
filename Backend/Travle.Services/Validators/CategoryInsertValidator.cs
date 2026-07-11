

using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class CategoryInsertValidator : AbstractValidator<CategoriesInsertRequest>
    {
        public CategoryInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Name is required.")
                .MaximumLength(50).WithMessage("Name cannot exceed 50 characters.")
                .MinimumLength(4).WithMessage("Name must have at least 4 characters");

                RuleFor(x => x.Description)
                .MaximumLength(1000).WithMessage("Description cannot exceed 1000 characters.");
        }
    }
}
