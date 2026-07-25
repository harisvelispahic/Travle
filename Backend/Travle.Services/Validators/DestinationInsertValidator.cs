using Travle.Model.Requests;
using Travle.Services.Security;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a destination submission. Existence of the category/city/tags and the
    /// magic-byte check on each image are business rules verified in the service (they need the database
    /// and the raw bytes).
    /// </summary>
    public class DestinationInsertValidator : AbstractValidator<DestinationInsertRequest>
    {
        public DestinationInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A name is required.")
                .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

            RuleFor(x => x.Description)
                .NotEmpty().WithMessage("A description is required.")
                .MaximumLength(4000).WithMessage("Description cannot exceed 4000 characters.");

            RuleFor(x => x.CategoryId)
                .GreaterThan(0).WithMessage("A category must be selected.");

            RuleFor(x => x.CityId)
                .GreaterThan(0).WithMessage("A city must be selected.");

            RuleFor(x => x.Latitude)
                .InclusiveBetween(-90, 90).WithMessage("Latitude must be between -90 and 90.");

            RuleFor(x => x.Longitude)
                .InclusiveBetween(-180, 180).WithMessage("Longitude must be between -180 and 180.");

            RuleForEach(x => x.Images).SetValidator(new DestinationImageValidator());
        }
    }
}
