using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a new schedule slot. The future-start check is repeated in the service (the
    /// authoritative precondition, raised as a business-rule error), but validating it here surfaces the
    /// message under the control on the organizer form before the request is sent.
    /// </summary>
    public class TourScheduleInsertValidator : AbstractValidator<TourScheduleInsertRequest>
    {
        public TourScheduleInsertValidator()
        {
            RuleFor(x => x.StartsAt)
                .GreaterThan(_ => DateTime.UtcNow)
                .WithMessage("The start date and time must be in the future.");

            RuleFor(x => x.Capacity)
                .InclusiveBetween(1, 1000)
                .When(x => x.Capacity.HasValue)
                .WithMessage("Capacity must be between 1 and 1000.");
        }
    }
}
