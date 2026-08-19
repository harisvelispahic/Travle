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

            // Optional; a real IANA id is verified against the zone database in CityService.
            RuleFor(x => x.TimeZoneId)
                .MaximumLength(64).WithMessage("Time zone id cannot exceed 64 characters.")
                .When(x => !string.IsNullOrWhiteSpace(x.TimeZoneId));
        }
    }
}
