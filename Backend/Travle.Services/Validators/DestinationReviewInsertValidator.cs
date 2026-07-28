using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for a new destination review: a valid target, a 1–5 rating, and an optional comment
    /// within the 1000-character limit. Cross-row rules (approved target, one active review per user) are
    /// enforced in the service where the database is available.
    /// </summary>
    public class DestinationReviewInsertValidator : AbstractValidator<DestinationReviewInsertRequest>
    {
        public DestinationReviewInsertValidator()
        {
            RuleFor(x => x.DestinationId)
                .GreaterThan(0).WithMessage("A destination must be selected.");

            RuleFor(x => x.Rating)
                .InclusiveBetween(1, 5).WithMessage("Rating must be between 1 and 5 stars.");

            RuleFor(x => x.Comment)
                .MaximumLength(1000).WithMessage("A comment cannot exceed 1000 characters.");
        }
    }
}
