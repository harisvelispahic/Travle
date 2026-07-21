using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Read-only endpoint (list + get by id). Booking statuses are seeded reference data the state machine
/// depends on, so they are never written through the API — hence <see cref="BaseReadController{TResponse, TSearch, TService}"/>.
/// Reads require an authenticated user, consistent with the other reference-data endpoints.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class BookingStatusesController
    : BaseReadController<BookingStatusResponse, BookingStatusSearch, IBookingStatusService>
{
    public BookingStatusesController(IBookingStatusService service) : base(service)
    {
    }
}
