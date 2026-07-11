using System.ComponentModel.DataAnnotations;

namespace Travle.Model.Requests
{
    public class ProductUpdateRequest
    {
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
        
        public string Description { get; set; } = string.Empty;

        [Required]
        public decimal Price { get; set; }
        
        public int StockQuantity { get; set; } = 0;
        
        public bool IsActive { get; set; } = true;
        
        // SKU (Stock Keeping Unit) for inventory management
        [MaxLength(50)]
        public string? SKU { get; set; }
        
        // Product weight for shipping calculations (in grams)
        public decimal? Weight { get; set; }
        
        // Product Type relationship
        public int? ProductTypeId { get; set; }
                
        // Unit of Measure relationship
        public int? UnitOfMeasureId { get; set; }
        public List<AssetInsertRequest>? Assets { get; set; }
    }
}
