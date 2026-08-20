using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class BookingOrganizerCancelValidator : AbstractValidator<BookingOrganizerCancelRequest>
    {
        public BookingOrganizerCancelValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A cancellation reason is required.")
                .MaximumLength(500).WithMessage("The cancellation reason cannot exceed 500 characters.");
        }
    }
}
