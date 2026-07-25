using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for an admin's destination rejection: a reason is mandatory (stored for audit and
    /// shown to the submitter in the notification).
    /// </summary>
    public class DestinationRejectValidator : AbstractValidator<DestinationRejectRequest>
    {
        public DestinationRejectValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A rejection reason is required.")
                .MaximumLength(500).WithMessage("The reason cannot exceed 500 characters.");
        }
    }
}
