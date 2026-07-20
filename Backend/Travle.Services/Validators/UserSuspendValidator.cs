using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class UserSuspendValidator : AbstractValidator<UserSuspendRequest>
    {
        public UserSuspendValidator()
        {
            RuleFor(x => x.Reason)
                .NotEmpty().WithMessage("A suspension reason is required.")
                .MaximumLength(500).WithMessage("The suspension reason cannot exceed 500 characters.");
        }
    }
}
