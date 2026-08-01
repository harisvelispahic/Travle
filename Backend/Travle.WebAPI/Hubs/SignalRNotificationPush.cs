using Travle.Model.Responses;
using Travle.Services.Notifications;
using Microsoft.AspNetCore.SignalR;

namespace Travle.WebAPI.Hubs;

/// <summary>
/// SignalR implementation of <see cref="INotificationRealtimePush"/>: sends the notification to the
/// recipient's <c>user-{id}</c> group via the hub's <see cref="NotificationReceived"/> client method. The
/// client registers a handler for that method name to render the live notification and bump its badge.
/// </summary>
public sealed class SignalRNotificationPush : INotificationRealtimePush
{
    /// <summary>The client-side method name the server invokes; the Flutter client subscribes to this.</summary>
    public const string NotificationReceived = "NotificationReceived";

    private readonly IHubContext<NotificationHub> _hub;

    public SignalRNotificationPush(IHubContext<NotificationHub> hub)
    {
        _hub = hub;
    }

    public Task PushAsync(int userId, NotificationResponse notification, CancellationToken cancellationToken = default)
        => _hub.Clients.Group(NotificationHub.GroupName(userId))
               .SendAsync(NotificationReceived, notification, cancellationToken);
}
