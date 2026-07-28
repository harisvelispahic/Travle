using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for an admin's review removal: a reason is mandatory (stored for audit and shown to the
    /// author in the removal notification).
    /// </summary>
    public class ReviewRemoveValidator : AbstractValidator<ReviewRemoveRequest>
    {
        public ReviewRemoveValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A removal reason is required.")
                .MaximumLength(500).WithMessage("The reason cannot exceed 500 characters.");
        }
    }
}
