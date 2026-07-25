using Travle.Model.Requests;
using Travle.Services.Security;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for one entry in a destination edit's image set. An entry keeps an existing
    /// image (its <c>Id</c> is set) or adds a new one (its <c>Data</c> + <c>ContentType</c> are set) —
    /// exactly one of those must hold. New-image bytes are magic-byte verified in the service.
    /// </summary>
    public class DestinationImageEditItemValidator : AbstractValidator<DestinationImageEditItem>
    {
        public DestinationImageEditItemValidator()
        {
            RuleFor(x => x)
                .Must(item => item.Id.HasValue ^ (item.Data is { Length: > 0 }))
                .WithMessage("Each image must either reference an existing image or contain new image data, not both or neither.");

            // When it's a new image, the declared content type must be an accepted image type.
            RuleFor(x => x.ContentType)
                .NotEmpty().WithMessage("An image content type is required.")
                .Must(ct => ct is not null && FileSignatureValidator.ImageContentTypes.Contains(ct.Trim()))
                .WithMessage($"Images must be one of: {string.Join(", ", FileSignatureValidator.ImageContentTypes)}.")
                .When(x => !x.Id.HasValue);
        }
    }
}
