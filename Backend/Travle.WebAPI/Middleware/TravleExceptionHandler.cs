using System.Collections.Generic;
using Microsoft.AspNetCore.Diagnostics;
using Travle.Model.Exceptions;
using Travle.Model.Responses;

namespace Travle.WebAPI.Middleware;

/// <summary>
/// First link in the exception-handler chain: handles the <see cref="TravleException"/>
/// hierarchy — the application's own expected, client-facing errors. Each exception carries its
/// own <see cref="TravleException.StatusCode"/> and <see cref="TravleException.ErrorKey"/>, so
/// this single handler covers all of NotFound / BusinessRule / Conflict / Unauthorized /
/// Forbidden / Payment without a per-type branch.
/// <para>
/// Anything it does not recognise is passed on (<c>return false</c>) to the next handler in the
/// chain, mirroring a <c>catch (TravleException)</c> block.
/// </para>
/// </summary>
public sealed class TravleExceptionHandler(ILogger<TravleExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not TravleException ex)
        {
            return false; // not one of ours — let the next handler in the chain try
        }

        var traceId = ErrorResponseWriter.ResolveTraceId(httpContext);

        // Expected domain error, not a system fault: log at Warning with enough context to trace it.
        logger.LogWarning(ex,
            "Handled domain exception {ExceptionType} ({StatusCode}) on {Method} {Path}. TraceId: {TraceId}",
            ex.GetType().Name, (int)ex.StatusCode, httpContext.Request.Method, httpContext.Request.Path, traceId);

        if (httpContext.Response.HasStarted)
        {
            logger.LogWarning("Response already started; cannot write error body for {ExceptionType}. TraceId: {TraceId}",
                ex.GetType().Name, traceId);
            return false;
        }

        var body = new ErrorResponse
        {
            Message = ex.Message,
            Errors = new Dictionary<string, string[]> { [ex.ErrorKey] = [ex.Message] },
            TraceId = traceId
        };

        await ErrorResponseWriter.WriteAsync(httpContext, ex.StatusCode, body, cancellationToken);
        return true; // handled — stops the chain
    }
}
