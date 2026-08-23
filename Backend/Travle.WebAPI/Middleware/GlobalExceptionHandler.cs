using System.Collections.Generic;
using System.Net;
using Microsoft.AspNetCore.Diagnostics;
using Travle.Model.Responses;

namespace Travle.WebAPI.Middleware;

/// <summary>
/// Terminal link in the chain (registered last): the catch-all for anything the more specific
/// handlers did not claim. Every such exception is an <b>unexpected/infrastructure</b> failure,
/// so it is logged in full — with the stack trace and the <c>TraceId</c> — and reported to the
/// client as a generic HTTP 500 carrying <b>no internal detail at all</b>. The response never
/// includes a stack trace in any environment, development included: a developer reads it from the
/// log the <c>TraceId</c> points at. This is the layer that guarantees internals never leak to a
/// client (course constraint §3.4 / §8.1).
/// </summary>
public sealed class GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
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
            TraceId = traceId
        };

        await ErrorResponseWriter.WriteAsync(httpContext, HttpStatusCode.InternalServerError, body, cancellationToken);
        return true; // always handles — nothing bubbles past the end of the chain
    }
}
