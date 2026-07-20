using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Profile-edit validation. Every field is optional (partial update), so each rule only fires
    /// when its field is supplied — editing one field never demands re-entering the others (§I).
    /// </summary>
    public class UserUpdateValidator : AbstractValidator<UserUpdateRequest>
    {
        public UserUpdateValidator()
        {
            RuleFor(x => x.FirstName)
                .NotEmpty().WithMessage("First name cannot be blank.")
                .MaximumLength(50).WithMessage("First name cannot exceed 50 characters.")
                .When(x => x.FirstName is not null);

            RuleFor(x => x.LastName)
                .NotEmpty().WithMessage("Last name cannot be blank.")
                .MaximumLength(50).WithMessage("Last name cannot exceed 50 characters.")
                .When(x => x.LastName is not null);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email cannot be blank.")
                .EmailAddress().WithMessage("Email must be a valid email address.")
                .MaximumLength(100).WithMessage("Email cannot exceed 100 characters.")
                .When(x => x.Email is not null);

            RuleFor(x => x.Username)
                .MinimumLength(3).WithMessage("Username must be at least 3 characters.")
                .MaximumLength(100).WithMessage("Username cannot exceed 100 characters.")
                .When(x => x.Username is not null);

            RuleFor(x => x.PhoneNumber)
                .MaximumLength(20).WithMessage("Phone number cannot exceed 20 characters.")
                .When(x => !string.IsNullOrEmpty(x.PhoneNumber));
        }
    }
}
