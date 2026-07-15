using System.Collections.Generic;
using System.Net;
using Microsoft.AspNetCore.Diagnostics;
using Travle.Model.Responses;

namespace Travle.WebAPI.Middleware;

/// <summary>
/// Terminal link in the chain (registered last): the catch-all for anything the more specific
/// handlers did not claim. Every such exception is an <b>unexpected/infrastructure</b> failure,
/// so it is logged in full (this is the only record of it) and reported to the client as a
/// generic HTTP 500 with <b>no internal detail</b> — the stack trace is attached only in the
/// Development environment. This is the layer that guarantees stack traces never leak to
/// production clients (course constraint §3.4 / §8.1).
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger, IHostEnvironment environment) : IExceptionHandler
{
    private const string SafeMessage = "An unexpected error occurred. Please try again later.";

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var traceId = ErrorResponseWriter.ResolveTraceId(httpContext);

        logger.LogError(exception,
            "Unhandled exception on {Method} {Path}. TraceId: {TraceId}. User: {User}",
            httpContext.Request.Method,
            httpContext.Request.Path,
            traceId,
            httpContext.User.Identity?.Name ?? "anonymous");

        if (httpContext.Response.HasStarted)
        {
            logger.LogWarning("Response already started; unable to write 500 error body. TraceId: {TraceId}", traceId);
            return false;
        }

        var body = new ErrorResponse
        {
            Message = SafeMessage,
            Errors = new Dictionary<string, string[]> { ["server"] = [SafeMessage] },
            TraceId = traceId,
            Details = environment.IsDevelopment() ? exception.ToString() : null // stack trace ONLY in Development
        };

        await ErrorResponseWriter.WriteAsync(httpContext, HttpStatusCode.InternalServerError, body, cancellationToken);
        return true; // always handles — nothing bubbles past the end of the chain
    }
}
