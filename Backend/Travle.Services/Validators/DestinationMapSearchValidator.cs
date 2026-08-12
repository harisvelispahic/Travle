using Travle.Model.SearchObjects;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Validation for the map-browse bounding box: all four edges are required (the bbox is the mandatory
    /// search parameter), each edge must sit within valid WGS84 ranges, and the box must be well-formed
    /// (south below north, west below east). An invalid box is a client mistake, so it fails fast here
    /// rather than reaching the query.
    /// </summary>
    public class DestinationMapSearchValidator : AbstractValidator<DestinationMapSearch>
    {
        public DestinationMapSearchValidator()
        {
            RuleFor(x => x.South)
                .NotNull().WithMessage("The map bounds are required.")
                .InclusiveBetween(-90, 90).WithMessage("Latitude must be between -90 and 90.");

            RuleFor(x => x.North)
                .NotNull().WithMessage("The map bounds are required.")
                .InclusiveBetween(-90, 90).WithMessage("Latitude must be between -90 and 90.");

            RuleFor(x => x.West)
                .NotNull().WithMessage("The map bounds are required.")
                .InclusiveBetween(-180, 180).WithMessage("Longitude must be between -180 and 180.");

            RuleFor(x => x.East)
                .NotNull().WithMessage("The map bounds are required.")
                .InclusiveBetween(-180, 180).WithMessage("Longitude must be between -180 and 180.");

            RuleFor(x => x)
                .Must(x => x.South < x.North)
                .When(x => x.South.HasValue && x.North.HasValue)
                .WithMessage("The southern edge must be below the northern edge.");

            RuleFor(x => x)
                .Must(x => x.West < x.East)
                .When(x => x.West.HasValue && x.East.HasValue)
                .WithMessage("The western edge must be to the west of the eastern edge.");

            RuleFor(x => x.MinRating)
                .InclusiveBetween(0, 5).WithMessage("The minimum rating must be between 0 and 5.")
                .When(x => x.MinRating.HasValue);
        }
    }
}
