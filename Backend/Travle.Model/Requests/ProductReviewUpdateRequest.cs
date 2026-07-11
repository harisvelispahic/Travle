namespace Travle.Model.Requests;

public class ProductReviewUpdateRequest
{
    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;
}
