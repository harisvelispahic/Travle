namespace Travle.Model.Requests;

public class ProductReviewInsertRequest
{
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public int Rating { get; set; }
    public string Comment { get; set; } = string.Empty;
}
