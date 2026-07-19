using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Read-only endpoint (list + get by id). Booking statuses are seeded reference data the state machine
/// depends on, so they are never written through the API — hence <see cref="BaseReadController{TResponse, TSearch, TService}"/>.
/// </summary>
[ApiController]
[Route("[controller]")]
public class BookingStatusesController
    : BaseReadController<BookingStatusResponse, BookingStatusSearch, IBookingStatusService>
{
    public BookingStatusesController(IBookingStatusService service) : base(service)
    {
    }
}
