namespace Travle.Model.Responses
{
    public class ProductResponse
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public int StockQuantity { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public string? SKU { get; set; }
        public decimal? Weight { get; set; }
        public int? ProductTypeId { get; set; }
        public int? UnitOfMeasureId { get; set; }

        public string ProductState { get; set; }
        public ProductTypeResponse ProductType { get; set; }
        public List<string> AllowedActions { get; set; } = new List<string>();
        public List<AssetResponse> Assets { get; set; } = new List<AssetResponse>();

        public List<ProductReviewResponse> Reviews { get; set; } = new List<ProductReviewResponse>();
    }
}