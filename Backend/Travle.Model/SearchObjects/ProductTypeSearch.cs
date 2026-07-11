namespace Travle.Model.SearchObjects
{
    public class ProductTypeSearch : BaseSearchObject
    {
        /// <summary>
        /// Substring to match against the product type name (case-insensitive).
        /// </summary>
        public string? Name { get; set; }

        /// <summary>
        /// Filter product types by their active status.
        /// </summary>
        public bool? IsActive { get; set; }
    }
}
