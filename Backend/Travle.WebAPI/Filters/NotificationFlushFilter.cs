using Travle.Services.Notifications;
using Microsoft.AspNetCore.Mvc.Filters;

namespace Travle.WebAPI.Filters;

/// <summary>
/// After a controller action completes without throwing, flushes the request-scoped
/// <see cref="INotificationDispatcher"/> so every notification staged during the action is delivered
/// (SignalR push + email for the flagged subset) — but only once its transaction has committed, which it
/// has by the time the action returns. On an exception the flush is skipped; the row, if it committed,
/// still surfaces on the next REST load. Registered globally, so no controller has to remember to flush.
/// The filter is resolved per request, so it shares the same scoped dispatcher the action's services used.
/// </summary>
public sealed class NotificationFlushFilter : IAsyncActionFilter
{
    private readonly INotificationDispatcher _dispatcher;

    public NotificationFlushFilter(INotificationDispatcher dispatcher)
    {
        _dispatcher = dispatcher;
    }

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var executed = await next();
        if (executed.Exception is null)
        {
            await _dispatcher.FlushAsync(context.HttpContext.RequestAborted);
        }
    }
}
