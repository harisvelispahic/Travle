using System.Net;
using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Travle.Model.Responses;

namespace Travle.WebAPI.Middleware;

/// <summary>
/// Second link in the chain: translates a <see cref="ValidationException"/> raised by
/// FluentValidation (thrown from the service layer when a request fails its validator) into an
/// HTTP 400 whose <c>errors</c> dictionary is keyed by property name, so the Flutter clients can
/// show each message under the corresponding control.
/// <para>Non-validation exceptions are passed on to the fallback handler.</para>
/// </summary>
public sealed class ValidationExceptionHandler(ILogger<ValidationExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not ValidationException ex)
        {
            return false; // not a validation failure — let the next handler try
        }

        var traceId = ErrorResponseWriter.ResolveTraceId(httpContext);

        logger.LogWarning(
            "Validation failed on {Method} {Path} with {Count} error(s). TraceId: {TraceId}",
            httpContext.Request.Method, httpContext.Request.Path, ex.Errors.Count(), traceId);

        if (httpContext.Response.HasStarted)
        {
            logger.LogWarning("Response already started; cannot write validation error body. TraceId: {TraceId}", traceId);
            return false;
        }

        // Group by property so all messages for one field arrive together; blank keys (model-level
        // rules) fall under "request".
        var errors = ex.Errors
            .GroupBy(e => string.IsNullOrEmpty(e.PropertyName) ? "request" : e.PropertyName)
            .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).Distinct().ToArray());

        var message = ex.Errors.Select(e => e.ErrorMessage).FirstOrDefault()
                      ?? "One or more validation errors occurred.";

        var body = new ErrorResponse
        {
            Message = message,
            Errors = errors,
            TraceId = traceId
        };

        await ErrorResponseWriter.WriteAsync(httpContext, HttpStatusCode.BadRequest, body, cancellationToken);
        return true;
    }
}
