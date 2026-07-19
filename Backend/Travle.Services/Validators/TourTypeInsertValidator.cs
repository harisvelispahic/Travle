using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class TourTypeInsertValidator : AbstractValidator<TourTypeInsertRequest>
    {
        public TourTypeInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Tour type name is required.")
                .MaximumLength(100).WithMessage("Tour type name cannot exceed 100 characters.");
        }
    }
}
