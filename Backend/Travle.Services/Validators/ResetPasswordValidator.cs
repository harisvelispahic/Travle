using Travle.Model.Access;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class ResetPasswordValidator : AbstractValidator<ResetPasswordRequest>
    {
        public ResetPasswordValidator()
        {
            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email is required.")
                .EmailAddress().WithMessage("Email must be a valid email address.");

            RuleFor(x => x.Code)
                .NotEmpty().WithMessage("The reset code is required.")
                .Matches(@"^\d{6}$").WithMessage("The reset code must be a 6-digit number.");

            RuleFor(x => x.NewPassword)
                .NotEmpty().WithMessage("New password is required.")
                .MinimumLength(8).WithMessage("New password must be at least 8 characters.")
                .MaximumLength(100).WithMessage("New password cannot exceed 100 characters.");

            RuleFor(x => x.ConfirmNewPassword)
                .Equal(x => x.NewPassword).WithMessage("Password confirmation does not match the new password.");
        }
    }
}
