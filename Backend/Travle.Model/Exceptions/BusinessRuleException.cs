using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when a request is well-formed but violates a domain rule (e.g. reviewing a booking
/// that is not yet completed, cancelling an already-cancelled booking). Maps to HTTP 400
/// (Bad Request). This is the direct replacement for the template's old <c>ClientException</c>.
/// </summary>
public sealed class BusinessRuleException : TravleException
{
    public BusinessRuleException(string message)
        : base(message, HttpStatusCode.BadRequest, "businessRule")
    {
    }

    public BusinessRuleException(string message, Exception innerException)
        : base(message, HttpStatusCode.BadRequest, "businessRule", innerException)
    {
    }
}
