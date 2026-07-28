using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for a favorite toggle: exactly one target must be set — a destination or a tour, never
    /// both and never neither (mirrors the entity's <c>CK_Favorite_ExactlyOneTarget</c> constraint).
    /// </summary>
    public class FavoriteToggleValidator : AbstractValidator<FavoriteToggleRequest>
    {
        public FavoriteToggleValidator()
        {
            RuleFor(x => x)
                .Must(x => (x.DestinationId.HasValue) ^ (x.TourId.HasValue))
                .WithMessage("Provide exactly one target: a destination or a tour.");
        }
    }
}
