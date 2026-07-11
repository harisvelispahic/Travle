using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class UnitOfMeasureInsertValidator : AbstractValidator<UnitOfMeasureInsertRequest>
    {
        public UnitOfMeasureInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Name is required.")
                .MaximumLength(50).WithMessage("Name cannot exceed 50 characters.")
                .MinimumLength(2).WithMessage("Name must have at least 2 characters.");

            RuleFor(x => x.Abbreviation)
                .NotEmpty().WithMessage("Abbreviation is required.")
                .MaximumLength(10).WithMessage("Abbreviation cannot exceed 10 characters.");

            RuleFor(x => x.Description)
                .MaximumLength(500).WithMessage("Description cannot exceed 500 characters.");
        }
    }
}
