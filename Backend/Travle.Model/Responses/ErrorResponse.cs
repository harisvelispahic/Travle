namespace Travle.Model.Responses;

/// <summary>
/// Standard error envelope returned by the API for every non-success response.
/// <para>
/// The shape matches what the Flutter clients expect: a human-readable <see cref="Message"/>
/// for snackbars/dialogs, plus a per-key <see cref="Errors"/> dictionary the UI renders under
/// the relevant control (the key is the property name for validation failures, or the error
/// category — e.g. <c>"notFound"</c>, <c>"businessRule"</c>, <c>"server"</c> — for domain and
/// unexpected failures).
/// </para>
/// <para>
/// <see cref="TraceId"/> is always populated so a user can quote an id that ties back to the
/// server logs — which is where exception detail lives. <b>No environment, development included,
/// ever puts a stack trace or any other internal detail in this envelope</b> (course §3.4/§8.1):
/// the full exception is logged server-side against the same <see cref="TraceId"/>.
/// </para>
/// </summary>
public sealed class ErrorResponse
{
    /// <summary>Human-readable summary safe to display to the end user.</summary>
    public string Message { get; set; } = default!;

    /// <summary>
    /// Error messages grouped by key. For validation failures the key is the offending property
    /// name; for domain/unexpected failures it is the error category.
    /// </summary>
    public IDictionary<string, string[]> Errors { get; set; } = new Dictionary<string, string[]>();

    /// <summary>Correlation id that matches the server-side log entry for this failure.</summary>
    public string? TraceId { get; set; }
}
