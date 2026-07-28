using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;

namespace Travle.Services
{
    public class BookingStatusService
        : BaseReadService<BookingStatus, BookingStatusResponse, BookingStatusSearch>,
          IBookingStatusService
    {
        public BookingStatusService(MapsterMapper.IMapper mapper, TravleDbContext dbContext)
            : base(mapper, dbContext)
        {
        }

        protected override IQueryable<BookingStatus> ApplyFilters(IQueryable<BookingStatus> query, BookingStatusSearch? search)
        {
            query = query.WhereContains(search?.Name, s => s.Name);

            return query;
        }
    }
}
