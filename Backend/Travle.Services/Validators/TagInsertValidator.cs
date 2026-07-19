using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    public class TagInsertValidator : AbstractValidator<TagInsertRequest>
    {
        public TagInsertValidator()
        {
            RuleFor(x => x.Name)
                .NotEmpty().WithMessage("Tag name is required.")
                .MaximumLength(50).WithMessage("Tag name cannot exceed 50 characters.");
        }
    }
}
