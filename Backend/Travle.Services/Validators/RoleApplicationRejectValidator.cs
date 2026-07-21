using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class RoleApplicationRejectValidator : AbstractValidator<RoleApplicationRejectRequest>
    {
        public RoleApplicationRejectValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A rejection reason is required.")
                .MaximumLength(500).WithMessage("The rejection reason cannot exceed 500 characters.");
        }
    }
}
