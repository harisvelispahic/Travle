using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape-only validation for a role application. Which roles are applicable (Curator/Organizer),
    /// whether the applicant already holds the role, and whether the region exists are business rules
    /// checked in the service, because they depend on the database.
    /// </summary>
    public class RoleApplicationSubmitValidator : AbstractValidator<RoleApplicationSubmitRequest>
    {
        public RoleApplicationSubmitValidator()
        {
            RuleFor(x => x.RoleId)
                .GreaterThan(0).WithMessage("A role must be selected.");

            RuleFor(x => x.Motivation)
                .NotEmpty().WithMessage("Please describe your motivation.")
                .MaximumLength(1000).WithMessage("Motivation cannot exceed 1000 characters.");

            RuleFor(x => x.RegionId)
                .GreaterThan(0).WithMessage("A valid region must be selected.")
                .When(x => x.RegionId.HasValue);

            // A document is optional, but if one is attached it must be non-empty and declare its type
            // (the type is then verified against the actual bytes in the service).
            RuleFor(x => x.Document)
                .NotEmpty().WithMessage("The attached document is empty.")
                .When(x => x.Document is not null);

            RuleFor(x => x.DocumentContentType)
                .NotEmpty().WithMessage("A document content type is required when a document is attached.")
                .When(x => x.Document is not null && x.Document.Length > 0);
        }
    }
}
