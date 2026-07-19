using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class RegionUpdateValidator : AbstractValidator<RegionUpdateRequest>
    {
        public RegionUpdateValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Region name is required.")
                .MaximumLength(100).WithMessage("Region name cannot exceed 100 characters.");

            RuleFor(x => x.CountryId)
                .GreaterThan(0).WithMessage("A country must be selected.");
        }
    }
}
