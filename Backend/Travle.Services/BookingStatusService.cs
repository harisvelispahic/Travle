using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Database;
using Microsoft.EntityFrameworkCore;

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
            if (!string.IsNullOrWhiteSpace(search?.Name))
            {
                query = SearchCollation.HasDiacritics(search.Name)
                    ? query.Where(s => EF.Functions.Collate(s.Name, SearchCollation.CaseInsensitiveAccentSensitive).Contains(search.Name))
                    : query.Where(s => EF.Functions.Collate(s.Name, SearchCollation.CaseInsensitiveAccentInsensitive).Contains(search.Name));
            }

            return query;
        }
    }
}
