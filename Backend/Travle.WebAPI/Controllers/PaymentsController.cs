using Travle.Model.Requests;
using Travle.Model.Responses;
using Travle.Services.Payments;
using Travle.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Travle.WebAPI.Controllers;

/// <summary>
/// Stripe-backed payments. The only client-facing action is starting a payment for a held booking; the
/// amount and platform-fee snapshot are computed server-side in the service, and payment success is
/// recorded solely by the signature-verified webhook (added in Phase 6b) — never reported by the client.
/// Payments are never CRUD-edited (docs/crud-endpoints.md).
/// </summary>
[ApiController]
[Route("[controller]")]
[Authorize(Policy = AuthPolicies.Authenticated)]
public class PaymentsController : ControllerBase
{
    private readonly IPaymentService _service;

    public PaymentsController(IPaymentService service)
    {
        _service = service;
    }

    /// <summary>
    /// Traveler starts (or resumes) paying for their own PaymentInProgress booking. Returns the Stripe
    /// PaymentIntent client secret for the mobile PaymentSheet. Ownership and the hold precondition are
    /// enforced in the service.
    /// </summary>
    [HttpPost("CreateIntent")]
    public async Task<ActionResult<PaymentIntentResponse>> CreateIntent(
        [FromBody] PaymentIntentCreateRequest request, CancellationToken cancellationToken)
        => Ok(await _service.CreateIntentAsync(request, cancellationToken));

    /// <summary>
    /// Stripe → Travle. Anonymous (Stripe isn't a logged-in user) but every request is signature-verified
    /// against the webhook secret in the service before anything is trusted. The <b>raw</b> body must be
    /// read byte-for-byte — the signature is computed over it, so we never let model binding touch it.
    /// This is the sole authority on payment success.
    /// </summary>
    [AllowAnonymous]
    [HttpPost("Webhook")]
    public async Task<IActionResult> Webhook(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);
        var json = await reader.ReadToEndAsync(cancellationToken);
        var signature = Request.Headers["Stripe-Signature"].ToString();

        await _service.HandleWebhookAsync(json, signature, cancellationToken);
        return Ok();
    }
}
