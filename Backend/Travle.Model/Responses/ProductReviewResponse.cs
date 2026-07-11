namespace Travle.Model.Responses;

public class ProductReviewResponse
{
    public int Id { get; set; }
    public int Rating { get; set; }
    public string Comment { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public int UserId { get; set; }
    public string ReviewerDisplayName { get; set; } = string.Empty;
    public int? OrderId { get; set; }
    public int? ProductId { get; set; }
}
