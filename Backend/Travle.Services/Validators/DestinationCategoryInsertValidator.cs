using Travle.Model.Requests;
using Travle.Services.Security;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class DestinationCategoryInsertValidator : AbstractValidator<DestinationCategoryInsertRequest>
    {
        public DestinationCategoryInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Category name is required.")
                .MaximumLength(100).WithMessage("Category name cannot exceed 100 characters.");

            RuleFor(x => x.Description)
                .MaximumLength(150).WithMessage("Description cannot exceed 150 characters.");

            // Shape only; the bytes are re-verified against the content type by magic bytes in the service.
            RuleFor(x => x.ImageContentType)
                .Must(ct => ct is not null && FileSignatureValidator.ImageContentTypes.Contains(ct.Trim()))
                .WithMessage($"Image must be one of: {string.Join(", ", FileSignatureValidator.ImageContentTypes)}.")
                .When(x => x.Image is { Length: > 0 });
        }
    }
}
