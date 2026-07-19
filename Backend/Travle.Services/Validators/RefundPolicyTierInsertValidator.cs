using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class RefundPolicyTierInsertValidator : AbstractValidator<RefundPolicyTierInsertRequest>
    {
        public RefundPolicyTierInsertValidator()
        {
            RuleFor(x => x.HoursBeforeMin)
                .GreaterThanOrEqualTo(0).WithMessage("Minimum hours before start cannot be negative.");

            RuleFor(x => x.HoursBeforeMax)
                .GreaterThan(x => x.HoursBeforeMin)
                .When(x => x.HoursBeforeMax.HasValue)
                .WithMessage("Maximum hours before start must be greater than the minimum.");

            RuleFor(x => x.Percentage)
                .InclusiveBetween(0, 100).WithMessage("Refund percentage must be between 0 and 100.");
        }
    }
}
