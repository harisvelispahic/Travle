using Travle.Model.Requests;
using Travle.Services.Security;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Profile-edit validation. Every field is optional (partial update), so each rule only fires
    /// when its field is supplied — editing one field never demands re-entering the others (§I).
    /// </summary>
    public class UserUpdateValidator : AbstractValidator<UserUpdateRequest>
    {
        // Cap the stored image so a request can't post an unbounded byte[] (5 MB).
        private const int MaxProfileImageBytes = 5 * 1024 * 1024;

        public UserUpdateValidator()
        {
            RuleFor(x => x.FirstName)
                .NotEmpty().WithMessage("First name cannot be blank.")
                .MaximumLength(50).WithMessage("First name cannot exceed 50 characters.")
                .When(x => x.FirstName is not null);

            RuleFor(x => x.LastName)
                .NotEmpty().WithMessage("Last name cannot be blank.")
                .MaximumLength(50).WithMessage("Last name cannot exceed 50 characters.")
                .When(x => x.LastName is not null);

            RuleFor(x => x.Email)
                .NotEmpty().WithMessage("Email cannot be blank.")
                .EmailAddress().WithMessage("Email must be a valid email address.")
                .MaximumLength(100).WithMessage("Email cannot exceed 100 characters.")
                .When(x => x.Email is not null);

            RuleFor(x => x.Username)
                .MinimumLength(3).WithMessage("Username must be at least 3 characters.")
                .MaximumLength(100).WithMessage("Username cannot exceed 100 characters.")
                .When(x => x.Username is not null);

            RuleFor(x => x.PhoneNumber)
                .MaximumLength(20).WithMessage("Phone number cannot exceed 20 characters.")
                .When(x => !string.IsNullOrEmpty(x.PhoneNumber));

            // Profile image (optional). When bytes are supplied, the declared type is required, must be
            // an allowed image type, and the payload is size-capped; the service then confirms the bytes
            // genuinely match the type via magic-byte sniffing.
            RuleFor(x => x.ProfileImageContentType)
                .NotEmpty().WithMessage("An image type is required when uploading a profile image.")
                .Must(ct => FileSignatureValidator.ImageContentTypes.Contains(ct, StringComparer.OrdinalIgnoreCase))
                    .WithMessage("The profile image must be a JPEG or PNG.")
                .When(x => x.ProfileImage is { Length: > 0 });

            RuleFor(x => x.ProfileImage)
                .Must(img => img!.Length <= MaxProfileImageBytes)
                    .WithMessage("The profile image must be 5 MB or smaller.")
                .When(x => x.ProfileImage is { Length: > 0 });

            // A declared image type with no bytes is not a valid partial update (would set a dangling type).
            RuleFor(x => x.ProfileImage)
                .NotNull().WithMessage("Image bytes are required when an image type is provided.")
                .When(x => !string.IsNullOrEmpty(x.ProfileImageContentType));
        }
    }
}
