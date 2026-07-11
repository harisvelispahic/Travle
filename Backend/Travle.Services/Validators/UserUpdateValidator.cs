using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class UserUpdateValidator : AbstractValidator<UserUpdateRequest>
    {
        public UserUpdateValidator()
        {
           
            RuleFor(x => x.FirstName)
                .NotEmpty().WithMessage("First name is required.")
                .MaximumLength(50).WithMessage("First name cannot exceed 50 characters.");
        }
    }
}
