using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when a request conflicts with the current state of a resource — a duplicate
/// (same user + same slot) or an attempt to delete reference data still in use. Maps to
/// HTTP 409 (Conflict).
/// </summary>
public sealed class ConflictException : TravleException
{
    public ConflictException(string message)
        : base(message, HttpStatusCode.Conflict, "conflict")
    {
    }
}
