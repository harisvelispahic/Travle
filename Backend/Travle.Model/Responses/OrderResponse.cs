namespace Travle.Model.Responses;

public class OrderResponse
{
    public int Id { get; set; }
    public DateTime OrderDate { get; set; }
    public string OrderNumber { get; set; } = string.Empty;
    public int Status { get; set; }
    public decimal TotalAmount { get; set; }
    public int UserId { get; set; }
    public List<OrderItemResponse> OrderItems { get; set; } = new();
}
