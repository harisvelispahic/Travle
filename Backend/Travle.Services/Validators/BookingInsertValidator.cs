using Travle.Model.Requests;
using FluentValidation;

namespace Travle.Services.Validators
{
    /// <summary>
    /// Shape validation for a new booking. Whether the slot exists, is active/future, the tour is active,
    /// and enough seats remain are business rules verified in the state machine (they need the database
    /// and a transactional capacity guard).
    /// </summary>
    public class BookingInsertValidator : AbstractValidator<BookingInsertRequest>
    {
        public BookingInsertValidator()
        {
            RuleFor(x => x.TourScheduleId)
                .GreaterThan(0).WithMessage("A schedule must be selected.");

            RuleFor(x => x.NumberOfPeople)
                .InclusiveBetween(1, 100)
                .WithMessage("The number of people must be between 1 and 100.");
        }
    }
}
