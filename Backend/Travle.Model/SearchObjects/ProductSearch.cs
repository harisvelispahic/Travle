namespace Travle.Model.SearchObjects
{
    public class ProductSearchObject : BaseSearchObject
    {
        /// <summary>
        /// Substring to match against product name (case-insensitive).
        /// </summary>
        public string? Name { get; set; }

        /// <summary>
        /// Substring to match against product description (case-insensitive).
        /// </summary>
        public string? Description { get; set; }

        /// <summary>
        /// Filter products by product type id.
        /// </summary>
        public int? ProductTypeId { get; set; }

        public string? ProductState { get; set; }

        public bool? IncludeProductType { get; set; }

        public bool? IncludeUnitOfMeasure { get; set; }
        public bool? IncludeAssets { get; set; }
    }
}