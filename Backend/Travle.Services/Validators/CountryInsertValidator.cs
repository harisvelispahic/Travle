using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class CountryInsertValidator : AbstractValidator<CountryInsertRequest>
    {
        public CountryInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Country name is required.")
                .MaximumLength(100).WithMessage("Country name cannot exceed 100 characters.");
        }
    }
}
