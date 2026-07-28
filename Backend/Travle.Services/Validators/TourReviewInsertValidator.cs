using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for a new tour review: a valid booking reference, a 1–5 rating, and an optional comment
    /// (≤1000). The booking-ownership / Completed-status / one-per-booking rules are enforced in the
    /// service where the database is available.
    /// </summary>
    public class TourReviewInsertValidator : AbstractValidator<TourReviewInsertRequest>
    {
        public TourReviewInsertValidator()
        {
            RuleFor(x => x.BookingId)
                .GreaterThan(0).WithMessage("A completed booking must be selected.");

            RuleFor(x => x.Rating)
                .InclusiveBetween(1, 5).WithMessage("Rating must be between 1 and 5 stars.");

            RuleFor(x => x.Comment)
                .MaximumLength(1000).WithMessage("A comment cannot exceed 1000 characters.");
        }
    }
}
