using Travle.Model.Responses;
using Travle.Model.SearchObjects;

namespace Travle.Services
{
    /// <summary>
    /// Read-only: booking statuses are seeded with load-bearing Ids/names the state machine depends on,
    /// so they are never created, edited or deleted through the API — only listed (e.g. for filters).
    /// </summary>
    public interface IBookingStatusService
        : IBaseReadService<BookingStatusResponse, BookingStatusSearch>
    {
    }
}
