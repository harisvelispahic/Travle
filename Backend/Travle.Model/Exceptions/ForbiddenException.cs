using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when the caller is authenticated but not allowed to perform the action — e.g.
/// modifying another user's data, or a suspended account attempting a restricted operation.
/// Maps to HTTP 403 (Forbidden).
/// </summary>
public sealed class ForbiddenException : TravleException
{
    public ForbiddenException(string message)
        : base(message, HttpStatusCode.Forbidden, "forbidden")
    {
    }
}
