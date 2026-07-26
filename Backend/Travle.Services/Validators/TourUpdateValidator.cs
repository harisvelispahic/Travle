using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a tour edit — identical rules to the insert (the request carries the same
    /// content fields). Tour-type existence and approved-destination checks stay in the service.
    /// </summary>
    public class TourUpdateValidator : AbstractValidator<TourUpdateRequest>
    {
        public TourUpdateValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("A name is required.")
                .MaximumLength(200).WithMessage("Name cannot exceed 200 characters.");

            RuleFor(x => x.Description)
                .NotEmpty().WithMessage("A description is required.")
                .MaximumLength(4000).WithMessage("Description cannot exceed 4000 characters.");

            RuleFor(x => x.DurationMinutes)
                .InclusiveBetween(1, 10080)
                .WithMessage("Duration must be between 1 minute and 7 days (10080 minutes).");

            RuleFor(x => x.PricePerPerson)
                .GreaterThan(0).WithMessage("Price per person must be greater than 0.")
                .LessThanOrEqualTo(100000).WithMessage("Price per person cannot exceed 100000 KM.");

            RuleFor(x => x.Capacity)
                .InclusiveBetween(1, 1000).WithMessage("Capacity must be between 1 and 1000.");

            RuleFor(x => x.TourTypeId)
                .GreaterThan(0).WithMessage("A tour type must be selected.");

            RuleFor(x => x.DestinationIds)
                .NotEmpty().WithMessage("A tour must visit at least one destination.")
                .Must(ids => ids.Distinct().Count() == ids.Count)
                .WithMessage("A destination cannot be listed twice on the same tour.");
        }
    }
}
