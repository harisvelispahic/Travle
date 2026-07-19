using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class CityUpdateValidator : AbstractValidator<CityUpdateRequest>
    {
        public CityUpdateValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("City name is required.")
                .MaximumLength(100).WithMessage("City name cannot exceed 100 characters.");

            RuleFor(x => x.RegionId)
                .GreaterThan(0).WithMessage("A region must be selected.");
        }
    }
}
