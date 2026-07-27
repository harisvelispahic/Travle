using Travle.Services.Database;
using MapsterMapper;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>Terminal state: a finished tour. No transitions (reviews are a separate Phase-7 flow).</summary>
    public class CompletedBookingState : BaseBookingState
    {
        public CompletedBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }
    }
}
