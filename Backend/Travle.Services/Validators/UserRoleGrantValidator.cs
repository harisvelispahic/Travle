using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class UserRoleGrantValidator : AbstractValidator<UserRoleGrantRequest>
    {
        public UserRoleGrantValidator()
        {
            RuleFor(x => x.RoleId)
                .GreaterThan(0).WithMessage("A role must be selected.");
        }
    }
}
