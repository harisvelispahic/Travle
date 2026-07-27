using Travle.Services.Database;
using MapsterMapper;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>Terminal state: a cancelled or rejected booking (kept as audit evidence, never deleted).</summary>
    public class CancelledBookingState : BaseBookingState
    {
        public CancelledBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }
    }
}
