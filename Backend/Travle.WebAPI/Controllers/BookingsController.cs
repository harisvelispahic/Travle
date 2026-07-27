using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Bookings and their lifecycle transitions. Creation and every transition run through the centralized
/// booking state machine in the service — this controller only maps HTTP verbs to service calls and
/// applies coarse policy gates; the fine-grained ownership checks (this booking is mine / this tour is
/// mine) live in the service so they hold no matter how the method is reached. Bookings are never
/// updated or deleted through the API (status machine only), so there is no PUT/DELETE here.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class BookingsController : ControllerBase
{
    private readonly IBookingService _service;

    public BookingsController(IBookingService service)
    {
        _service = service;
    }

    /// <summary>Admin-only: every booking, filterable and paginated (enforced in the service).</summary>
    [Authorize(Policy = AuthPolicies.AdminOnly)]
    [HttpGet]
    public async Task<ActionResult<PageResult<BookingResponse>>> GetAll([FromQuery] BookingSearch? search)
        => Ok(await _service.GetAllAsync(search));

    /// <summary>The current traveler's own bookings (their history), newest first.</summary>
    [HttpGet("mine")]
    public async Task<ActionResult<PageResult<BookingResponse>>> GetMine([FromQuery] BookingSearch? search)
        => Ok(await _service.GetMineAsync(search));

    /// <summary>Bookings on the current organizer's tours, newest first.</summary>
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpGet("my-tours")]
    public async Task<ActionResult<PageResult<BookingResponse>>> GetForMyTours([FromQuery] BookingSearch? search)
        => Ok(await _service.GetForMyToursAsync(search));

    /// <summary>Booking detail (owner, the tour's organizer, or admin — enforced in the service).</summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<BookingResponse>> GetById(int id)
        => Ok(await _service.GetByIdAsync(id));

    /// <summary>Traveler checkout: create a booking (PaymentInProgress with a 15-minute hold).</summary>
    [HttpPost]
    public async Task<ActionResult<BookingResponse>> Create([FromBody] BookingInsertRequest request)
        => StatusCode(StatusCodes.Status201Created, await _service.CreateAsync(request));

    /// <summary>Organizer confirms a pending booking on one of their tours.</summary>
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("{id}/Confirm")]
    public async Task<ActionResult<BookingResponse>> Confirm(int id)
        => Ok(await _service.ConfirmAsync(id));

    /// <summary>Organizer rejects a pending booking with a reason.</summary>
    [Authorize(Policy = AuthPolicies.OrganizerOnly)]
    [HttpPost("{id}/Reject")]
    public async Task<ActionResult<BookingResponse>> Reject(int id, [FromBody] BookingRejectRequest request)
        => Ok(await _service.RejectAsync(id, request));

    /// <summary>Traveler cancels their own booking (owner or admin — enforced in the service).</summary>
    [HttpPost("{id}/Cancel")]
    public async Task<ActionResult<BookingResponse>> Cancel(int id, [FromBody] BookingCancelRequest request)
        => Ok(await _service.CancelAsync(id, request));
}
