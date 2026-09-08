using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a whole-ladder replacement: each rung sane on its own terms. Whether the rungs
    /// form a valid ladder together — contiguous, single open end, rising percentages — is a cross-row rule
    /// checked by <c>RefundPolicyLadder.EnsureContiguous</c> in the service, which is also what guards the
    /// per-row CRUD endpoints.
    /// </summary>
    public class RefundPolicyLadderValidator : AbstractValidator<RefundPolicyLadderRequest>
    {
        public RefundPolicyLadderValidator()
        {
            RuleFor(x => x.Tiers)
                .NotEmpty().WithMessage("The refund policy must have at least one tier.");

            RuleForEach(x => x.Tiers).ChildRules(tier =>
            {
                tier.RuleFor(t => t.HoursBeforeMin)
                    .GreaterThanOrEqualTo(0).WithMessage("Minimum hours before start cannot be negative.");

                tier.RuleFor(t => t.HoursBeforeMax)
                    .GreaterThan(t => t.HoursBeforeMin)
                    .When(t => t.HoursBeforeMax.HasValue)
                    .WithMessage("Maximum hours before start must be greater than the minimum.");

                tier.RuleFor(t => t.Percentage)
                    .InclusiveBetween(0, 100).WithMessage("Refund percentage must be between 0 and 100.");
            });
        }
    }
}
