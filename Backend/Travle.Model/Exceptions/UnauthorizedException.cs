using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when the caller is not authenticated or presents invalid/expired credentials
/// (bad login, invalid or expired refresh token). Maps to HTTP 401 (Unauthorized).
/// </summary>
public sealed class UnauthorizedException : TravleException
{
    public UnauthorizedException(string message)
        : base(message, HttpStatusCode.Unauthorized, "unauthorized")
    {
    }
}
