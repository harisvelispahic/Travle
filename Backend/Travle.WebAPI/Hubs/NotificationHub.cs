using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace Travle.WebAPI.Hubs;

/// <summary>
/// Real-time channel for in-app notifications. Requires a valid JWT (carried in the <c>access_token</c>
/// query string on the WebSocket handshake — see the bearer <c>OnMessageReceived</c> wiring in Program.cs).
/// A connection's only group is the one named for its <b>own</b> authenticated user id, taken from the
/// validated token and never from client input, so a client can only ever receive its own notifications
/// (course §J — hubs verify membership). The server pushes to <c>user-{id}</c> via
/// <see cref="SignalRNotificationPush"/>; there are no client-to-server methods.
/// </summary>
[Authorize]
public sealed class NotificationHub : Hub
{
    public static string GroupName(int userId) => $"user-{userId}";

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        if (userId is null)
        {
            // No usable identity on the connection — refuse it rather than leave it in no group.
            Context.Abort();
            return;
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, GroupName(userId.Value));
        await base.OnConnectedAsync();
    }

    private int? GetUserId()
    {
        var id = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        return int.TryParse(id, out var userId) ? userId : null;
    }
}
