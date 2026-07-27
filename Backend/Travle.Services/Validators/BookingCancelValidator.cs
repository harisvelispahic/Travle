using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class BookingCancelValidator : AbstractValidator<BookingCancelRequest>
    {
        public BookingCancelValidator()
        {
            RuleFor(x => x.Reason)
                .MaximumLength(500).WithMessage("The cancellation reason cannot exceed 500 characters.")
                .When(x => !string.IsNullOrWhiteSpace(x.Reason));
        }
    }
}
