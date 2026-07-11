namespace Travle.Model.SearchObjects;

public class ProductReviewSearchObject : BaseSearchObject
{
    /// <summary>When the caller is an administrator, restricts results to reviews by this user.</summary>
    public int? UserId { get; set; }

    public int? ProductId { get; set; }

    public int? OrderId { get; set; }
    public int? Rating { get; set; }
}
