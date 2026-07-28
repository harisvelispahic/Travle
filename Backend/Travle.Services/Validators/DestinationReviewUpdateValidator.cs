using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>Validation for editing a destination review: a 1–5 rating and an optional comment (≤1000).</summary>
    public class DestinationReviewUpdateValidator : AbstractValidator<DestinationReviewUpdateRequest>
    {
        public DestinationReviewUpdateValidator()
        {
            RuleFor(x => x.Rating)
                .InclusiveBetween(1, 5).WithMessage("Rating must be between 1 and 5 stars.");

            RuleFor(x => x.Comment)
                .MaximumLength(1000).WithMessage("A comment cannot exceed 1000 characters.");
        }
    }
}
