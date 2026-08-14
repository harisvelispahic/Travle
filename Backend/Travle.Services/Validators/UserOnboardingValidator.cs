using Travle.Model.Requests;
using Travle.Services.Recommender;
using FluentValidation;
using Microsoft.Extensions.Options;

namespace Travle.Services.Validators
{
    public class UserOnboardingValidator : AbstractValidator<UserOnboardingRequest>
    {
        public UserOnboardingValidator(IOptions<RecommenderOptions> recommenderOptions)
        {
            var maxSelections = recommenderOptions.Value.MaxOnboardingSelections;

            RuleForEach(x => x.CategoryIds).GreaterThan(0).WithMessage("Category ids must be positive.");
            RuleForEach(x => x.TagIds).GreaterThan(0).WithMessage("Tag ids must be positive.");

            // Completing onboarding must carry at least one pick — otherwise it would mark the user onboarded
            // with no interest signals and no re-prompt. "No interests" is expressed by skipping (a client-side
            // snooze that never calls this endpoint), never by an empty completion.
            RuleFor(x => x)
                .Must(x => (x.CategoryIds?.Count ?? 0) + (x.TagIds?.Count ?? 0) >= 1)
                .WithMessage("Select at least one interest, or skip onboarding.");

            RuleFor(x => x)
                .Must(x => (x.CategoryIds?.Count ?? 0) + (x.TagIds?.Count ?? 0) <= maxSelections)
                .WithMessage($"You can select at most {maxSelections} interests in total.");
        }
    }
}
