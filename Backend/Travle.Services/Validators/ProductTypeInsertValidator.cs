using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class ProductTypeInsertValidator : AbstractValidator<ProductTypeInsertRequest>
    {
        public ProductTypeInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Name is required.")
                .MaximumLength(100).WithMessage("Name cannot exceed 100 characters.")
                .MinimumLength(2).WithMessage("Name must have at least 2 characters");

            RuleFor(x => x.Description)
                .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");
        }
    }
}
