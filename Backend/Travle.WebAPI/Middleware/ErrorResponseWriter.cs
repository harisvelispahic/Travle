using System.Diagnostics;
using System.Net;
using Travle.Model.Responses;

namespace Travle.WebAPI.Middleware;

/// <summary>
/// Shared helper for the exception-handler chain. Centralizes trace-id resolution and the
/// mechanics of writing an <see cref="ErrorResponse"/> to the HTTP response, so the individual
/// <see cref="Microsoft.AspNetCore.Diagnostics.IExceptionHandler"/> implementations stay small
/// and consistent (DRY).
/// </summary>
internal static class ErrorResponseWriter
{
    /// <summary>
    /// Resolves a correlation id for the current request, preferring the active
    /// <see cref="Activity"/> id (distributed tracing) and falling back to the connection's
    /// <see cref="HttpContext.TraceIdentifier"/>.
    /// </summary>
    public static string ResolveTraceId(HttpContext context)
        => Activity.Current?.Id ?? context.TraceIdentifier;

    /// <summary>
    /// Writes <paramref name="body"/> as JSON with the given status code. Assumes the caller has
    /// already checked <see cref="HttpResponse.HasStarted"/>.
    /// </summary>
    public static async ValueTask WriteAsync(
        HttpContext context,
        HttpStatusCode statusCode,
        ErrorResponse body,
        CancellationToken cancellationToken)
    {
        context.Response.StatusCode = (int)statusCode;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(body, cancellationToken);
    }
}
