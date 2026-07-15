using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Thrown when a payment operation fails (Stripe error, refund computation problem, an attempt
/// to pay an already-paid booking). Defaults to HTTP 402 (Payment Required); pass
/// <see cref="HttpStatusCode.BadRequest"/> for a malformed payment request that is the caller's
/// fault rather than a payment-processing failure.
/// </summary>
public sealed class PaymentException : TravleException
{
    public PaymentException(string message, HttpStatusCode statusCode = HttpStatusCode.PaymentRequired)
        : base(message, statusCode, "payment")
    {
    }

    public PaymentException(string message, Exception innerException, HttpStatusCode statusCode = HttpStatusCode.PaymentRequired)
        : base(message, statusCode, "payment", innerException)
    {
    }
}
