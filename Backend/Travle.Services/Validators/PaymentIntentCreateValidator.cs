using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for starting a payment. Whether the booking exists, is the caller's, is still in
    /// the PaymentInProgress hold and has not already been paid are business rules verified in the payment
    /// service (they need the database and the current user).
    /// </summary>
    public class PaymentIntentCreateValidator : AbstractValidator<PaymentIntentCreateRequest>
    {
        public PaymentIntentCreateValidator()
        {
            RuleFor(x => x.BookingId)
                .GreaterThan(0).WithMessage("A booking must be selected.");
        }
    }
}
