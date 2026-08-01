using Travle.Model.Responses;
using Travle.Model.SearchObjects;
using Travle.Services.Notifications;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// The current user's in-app notifications. Every action scopes to the JWT user (never a client-supplied
/// id), so a caller can only ever read or mutate their own notifications. Real-time delivery is over the
/// SignalR hub at <c>/hubs/notifications</c>; these endpoints back the initial load, the unread badge, and
/// mark-as-read.
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class NotificationsController : ControllerBase
{
    private readonly INotificationService _service;

    public NotificationsController(INotificationService service)
    {
        _service = service;
    }

    /// <summary>The current user's notifications, newest first, paginated; filter by read state or type.</summary>
    [HttpGet]
    public async Task<ActionResult<PageResult<NotificationResponse>>> Get([FromQuery] NotificationSearch? search)
        => Ok(await _service.GetMineAsync(search));

    /// <summary>The current user's unread count (for the bell badge).</summary>
    [HttpGet("unread-count")]
    public async Task<ActionResult<NotificationUnreadCountResponse>> GetUnreadCount()
        => Ok(new NotificationUnreadCountResponse { Count = await _service.GetUnreadCountAsync() });

    /// <summary>Mark one notification read (idempotent); 404 if it isn't the current user's.</summary>
    [HttpPut("{id:int}/read")]
    public async Task<ActionResult<NotificationResponse>> MarkRead(int id)
        => Ok(await _service.MarkReadAsync(id));

    /// <summary>Mark all of the current user's unread notifications read.</summary>
    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead()
    {
        await _service.MarkAllReadAsync();
        return NoContent();
    }
}
