using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class TourScheduleCancelValidator : AbstractValidator<TourScheduleCancelRequest>
    {
        public TourScheduleCancelValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A cancellation reason is required.")
                .MaximumLength(500).WithMessage("The cancellation reason cannot exceed 500 characters.");
        }
    }
}
