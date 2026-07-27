namespace Travle.Model.Requests
{
    /// <summary>
    /// A traveler's request to start paying for a held booking. Only the booking id comes from the client —
    /// the amount, currency and platform-fee snapshot are all computed server-side from the booking's
    /// stored total (never trusted from the client). The booking must be the caller's own and still in the
    /// PaymentInProgress hold; the server returns a Stripe PaymentIntent client secret for the PaymentSheet.
    /// </summary>
    public class PaymentIntentCreateRequest
    {
        public int BookingId { get; set; }
    }
}
