using Travle.Services.Database;
using MapsterMapper;

namespace Travle.Services.BookingStateMachine
{
    /// <summary>Terminal state: a hold that lapsed before payment. Kept as audit evidence of the expiry flow.</summary>
    public class ExpiredBookingState : BaseBookingState
    {
        public ExpiredBookingState(TravleDbContext dbContext, IMapper mapper, IServiceProvider serviceProvider)
            : base(dbContext, mapper, serviceProvider)
        {
        }
    }
}
