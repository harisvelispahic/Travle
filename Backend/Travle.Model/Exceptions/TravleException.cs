using System.Net;

namespace Travle.Model.Exceptions;

/// <summary>
/// Base type for every <b>expected, client-facing</b> Travle error.
/// <para>
/// Anything deriving from this is safe to surface to API clients: the global exception-handling
/// pipeline maps <see cref="StatusCode"/> onto the HTTP response and returns
/// <see cref="System.Exception.Message"/> to the caller verbatim. Infrastructure or otherwise
/// unexpected failures must <b>not</b> derive from this type — they are caught by the fallback
/// handler, logged in full, and reported to the client as a generic HTTP 500 with no internal
/// detail (see <c>docs/context/09-exception-handling.md</c>).
/// </para>
/// </summary>
public abstract class TravleException : Exception
{
    /// <summary>HTTP status code the pipeline returns for this error.</summary>
    public HttpStatusCode StatusCode { get; }

    /// <summary>
    /// Stable, machine-readable category placed as the key in the response <c>errors</c>
    /// dictionary (e.g. <c>"notFound"</c>, <c>"businessRule"</c>). Lets clients branch on the
    /// error category without parsing the human-readable message.
    /// </summary>
    public string ErrorKey { get; }

    protected TravleException(string message, HttpStatusCode statusCode, string errorKey, Exception? innerException = null)
        : base(message, innerException)
    {
        StatusCode = statusCode;
        ErrorKey = errorKey;
    }
}
