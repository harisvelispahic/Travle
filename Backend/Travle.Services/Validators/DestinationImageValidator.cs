using Travle.Model.Requests;
using Travle.Services.Security;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a newly attached destination image: the bytes must be present and the
    /// declared content type must be an accepted image type. The bytes are re-verified against the
    /// content type by magic-byte sniffing in the service (course §I — never trust the declared type).
    /// </summary>
    public class DestinationImageValidator : AbstractValidator<DestinationImageRequest>
    {
        public DestinationImageValidator()
        {
            RuleFor(x => x.Data)
                .NotEmpty().WithMessage("An image file is empty.");

            RuleFor(x => x.ContentType)
                .NotEmpty().WithMessage("An image content type is required.")
                .Must(ct => ct is not null && FileSignatureValidator.ImageContentTypes.Contains(ct.Trim()))
                .WithMessage($"Images must be one of: {string.Join(", ", FileSignatureValidator.ImageContentTypes)}.");
        }
    }
}
