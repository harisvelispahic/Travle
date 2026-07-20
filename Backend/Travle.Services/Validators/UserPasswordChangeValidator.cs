using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class UserPasswordChangeValidator : AbstractValidator<UserPasswordChangeRequest>
    {
        public UserPasswordChangeValidator()
        {
            RuleFor(x => x.CurrentPassword)
                .NotEmpty().WithMessage("Current password is required.");

            RuleFor(x => x.NewPassword)
                .NotEmpty().WithMessage("New password is required.")
                .MinimumLength(8).WithMessage("New password must be at least 8 characters.")
                .MaximumLength(100).WithMessage("New password cannot exceed 100 characters.")
                .NotEqual(x => x.CurrentPassword).WithMessage("New password must differ from the current password.");

            RuleFor(x => x.ConfirmNewPassword)
                .Equal(x => x.NewPassword).WithMessage("Password confirmation does not match the new password.");
        }
    }
}
