using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when a requested resource does not exist. Maps to HTTP 404 (Not Found).
/// </summary>
public sealed class NotFoundException : TravleException
{
    public NotFoundException(string message)
        : base(message, HttpStatusCode.NotFound, "notFound")
    {
    }

    /// <summary>
    /// Convenience overload producing a consistent "{Entity} with id {key} was not found." message.
    /// </summary>
    public NotFoundException(string entityName, object key)
        : base($"{entityName} with id {key} was not found.", HttpStatusCode.NotFound, "notFound")
    {
    }
}
