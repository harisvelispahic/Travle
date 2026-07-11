namespace Travle.Model.Requests;

public class CheckoutRequest
{
    public List<CheckoutLineRequest> Items { get; set; } = new();

    public string? ShippingAddress { get; set; }
    public string? ShippingCity { get; set; }
    public string? ShippingState { get; set; }
    public string? ShippingZipCode { get; set; }
    public string? ShippingCountry { get; set; }
}
